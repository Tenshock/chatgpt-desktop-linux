# shellcheck shell=bash

set -euo pipefail

write_metadata=false
source_dir=

while (( $# > 0 )); do
  case "$1" in
    --write)
      write_metadata=true
      shift
      ;;
    --source-dir)
      source_dir=$2
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

[[ -n $source_dir && -f $source_dir/source.json ]] || {
  echo "--source-dir must point at the package source directory" >&2
  exit 2
}
[[ -n ${CHATGPT_REPOSITORY_KEY:-} && -f $CHATGPT_REPOSITORY_KEY ]] || {
  echo "CHATGPT_REPOSITORY_KEY must point at the pinned repository key" >&2
  exit 2
}

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

metadata=$(jq -n '{ packages: {} }')
version=
repository_url=https://persistent.oaistatic.com/codex-app-prod/linux/deb
in_release="$work_dir/InRelease"
repository_keyring="$work_dir/openai-linux-repository.gpg"

gpg \
  --batch \
  --dearmor \
  --output "$repository_keyring" \
  "$CHATGPT_REPOSITORY_KEY"

curl \
  --fail \
  --location \
  --proto '=https' \
  --proto-redir '=https' \
  --retry 3 \
  --output "$in_release" \
  "$repository_url/dists/stable/InRelease"
gpgv --keyring "$repository_keyring" "$in_release"

for system in x86_64-linux aarch64-linux; do
  architecture=$(jq -er --arg system "$system" '.packages[$system].architecture' "$source_dir/source.json")
  packages_index_gz="$work_dir/Packages-${architecture}.gz"
  packages_index="$work_dir/Packages-${architecture}"
  package_path="$work_dir/chatgpt_${architecture}.deb"
  index_path="main/binary-${architecture}/Packages.gz"

  signed_index_sha256=$(awk -v path="$index_path" '
    $1 == "SHA256:" { in_sha256 = 1; next }
    in_sha256 && /^[^ ]/ { in_sha256 = 0 }
    in_sha256 && $3 == path { print $1; exit }
  ' "$in_release")
  [[ $signed_index_sha256 =~ ^[0-9a-f]{64}$ ]] || {
    echo "signed repository metadata has no SHA256 for $index_path" >&2
    exit 1
  }

  curl \
    --fail \
    --location \
    --proto '=https' \
    --proto-redir '=https' \
    --retry 3 \
    --output "$packages_index_gz" \
    "$repository_url/dists/stable/$index_path"

  downloaded_index_sha256=$(sha256sum "$packages_index_gz")
  downloaded_index_sha256=${downloaded_index_sha256%% *}
  [[ $downloaded_index_sha256 == "$signed_index_sha256" ]] || {
    echo "package index hash does not match signed repository metadata for $system" >&2
    exit 1
  }
  gzip -dc "$packages_index_gz" > "$packages_index"

  index_field() {
    local field=$1
    awk -v field="$field" '
      $1 == "Package:" && $2 == "chatgpt" { found = 1 }
      found && $1 == field ":" { print $2; exit }
    ' "$packages_index"
  }

  filename=$(index_field Filename)
  index_version=$(index_field Version)
  index_sha256=$(index_field SHA256)

  [[ $filename == pool/main/c/chatgpt/chatgpt_*_${architecture}.deb ]] || {
    echo "unexpected package filename for $system: $filename" >&2
    exit 1
  }
  [[ $index_version =~ ^[0-9]+([.][0-9]+)+$ ]] || {
    echo "unexpected package version for $system: $index_version" >&2
    exit 1
  }
  [[ $index_sha256 =~ ^[0-9a-f]{64}$ ]] || {
    echo "unexpected package hash for $system: $index_sha256" >&2
    exit 1
  }

  url="$repository_url/$filename"

  curl \
    --fail \
    --location \
    --proto '=https' \
    --proto-redir '=https' \
    --retry 3 \
    --output "$package_path" \
    "$url"

  package_name=$(dpkg-deb --field "$package_path" Package)
  package_architecture=$(dpkg-deb --field "$package_path" Architecture)
  package_version=$(dpkg-deb --field "$package_path" Version)
  downloaded_sha256=$(sha256sum "$package_path")
  downloaded_sha256=${downloaded_sha256%% *}

  [[ $package_name == chatgpt ]] || {
    echo "unexpected package name for $system: $package_name" >&2
    exit 1
  }
  [[ $package_architecture == "$architecture" ]] || {
    echo "unexpected architecture for $system: $package_architecture" >&2
    exit 1
  }
  [[ $package_version == "$index_version" ]] || {
    echo "package version does not match repository index for $system" >&2
    exit 1
  }
  [[ $downloaded_sha256 == "$index_sha256" ]] || {
    echo "package hash does not match repository index for $system" >&2
    exit 1
  }

  if [[ -z $version ]]; then
    version=$package_version
  elif [[ $package_version != "$version" ]]; then
    echo "official packages have different versions: $version and $package_version" >&2
    exit 1
  fi

  hash=$(nix hash file "$package_path")
  metadata=$(jq \
    --arg system "$system" \
    --arg architecture "$architecture" \
    --arg url "$url" \
    --arg hash "$hash" \
    '.packages[$system] = {
      architecture: $architecture,
      url: $url,
      hash: $hash
    }' <<< "$metadata")
done

metadata=$(jq --arg version "$version" '.version = $version' <<< "$metadata")
metadata=$(jq '{ version, packages }' <<< "$metadata")

echo "version: $version"
jq -r '.packages | to_entries[] | "\(.key): \(.value.hash)"' <<< "$metadata"

if $write_metadata; then
  metadata_tmp="$work_dir/source.json"
  jq . <<< "$metadata" > "$metadata_tmp"
  mv "$metadata_tmp" "$source_dir/source.json"
  echo "updated: $source_dir/source.json"
fi

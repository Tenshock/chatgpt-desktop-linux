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

product_id=$(jq -r .productId "$source_dir/source.json")
current_version=$(jq -r .version "$source_dir/source.json")
identity=$(jq -r .identity "$source_dir/source.json")
publisher=$(jq -r .publisher "$source_dir/source.json")
runtime_sha=$(jq -r .compatibility.owlRuntimeArchiveSha "$source_dir/source.json")
better_sqlite3=$(jq -r '.compatibility.nativeModules["better-sqlite3"]' "$source_dir/source.json")
node_pty=$(jq -r '.compatibility.nativeModules["node-pty"]' "$source_dir/source.json")
node_hid=$(jq -r '.compatibility.nativeModules["node-hid"]' "$source_dir/source.json")
serialport=$(jq -r '.compatibility.nativeModules["@serialport/bindings-cpp"]' "$source_dir/source.json")
codex_sha=$(jq -r '.compatibility.codex.bundledX64Sha256.codex' "$source_dir/source.json")
code_mode_host_sha=$(jq -r '.compatibility.codex.bundledX64Sha256["codex-code-mode-host"]' "$source_dir/source.json")
rg_sha=$(jq -r '.compatibility.codex.bundledX64Sha256.rg' "$source_dir/source.json")

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

for attempt in 1 2 3; do
  storelib_rs --log-level info packages "$product_id" \
    > "$work_dir/storelib.log" 2>&1 || true

  moniker=$(grep -Eo 'OpenAI\.Codex_[0-9.]+_x64__2p2nqsd0c76g0(\.msix)?' \
    "$work_dir/storelib.log" | head -n 1 || true)
  url=$(awk '
    /OpenAI\.Codex_[0-9.]+_x64__/ { wanted = 1; next }
    wanted && /Link received: https?:\/\// {
      sub(/^.*Link received: /, "")
      print
      exit
    }
  ' "$work_dir/storelib.log")

  [[ -n $moniker && -n $url ]] && break
  sleep "$attempt"
done

[[ -n ${moniker:-} && -n ${url:-} ]] || {
  echo "Store resolver returned no x64 OpenAI.Codex MSIX" >&2
  tail -n 20 "$work_dir/storelib.log" >&2
  exit 1
}

scheme=${url%%://*}
case "$scheme" in
  http | https) ;;
  *)
    echo "refusing unsupported Store delivery scheme: $scheme" >&2
    exit 1
    ;;
esac

host=${url#*://}
host=${host%%/*}
case "$host" in
  *.dl.delivery.mp.microsoft.com) ;;
  *)
    echo "refusing non-Microsoft Store delivery host: $host" >&2
    exit 1
    ;;
esac

version=${moniker#OpenAI.Codex_}
version=${version%%_x64__*}

if ! $write_metadata && [[ $version != "$current_version" ]]; then
  echo "Microsoft Store now serves ChatGPT $version, but this revision pins $current_version." >&2
  echo "Wait for repository metadata to be updated, or use scripts/update-source as a maintainer." >&2
  exit 1
fi

file_name="OpenAI.Codex_${version}_x64.msix"
download="$work_dir/$file_name"

curl \
  --cacert "$CHATGPT_STORE_CA_BUNDLE" \
  --fail \
  --location \
  --proto '=http,https' \
  --proto-redir '=https' \
  --retry 3 \
  --output "$download" \
  "$url"

verify-chatgpt-msix \
  "$download" \
  "$CHATGPT_MICROSOFT_ROOT_2010" \
  "$CHATGPT_MICROSOFT_ROOT_2011" \
  "$version" \
  "$identity" \
  "$publisher" \
  "$runtime_sha" \
  "$better_sqlite3" \
  "$node_pty" \
  "$node_hid" \
  "$serialport" \
  "$codex_sha" \
  "$code_mode_host_sha" \
  "$rg_sha"

sha256=$(nix hash file "$download")
store_path=$(nix-store --add-fixed sha256 "$download")

if $write_metadata; then
  metadata_tmp="$work_dir/source.json"
  jq \
    --arg version "$version" \
    --arg file_name "$file_name" \
    --arg sha256 "$sha256" \
    '.version = $version | .fileName = $file_name | .sha256 = $sha256' \
    "$source_dir/source.json" > "$metadata_tmp"
  mv "$metadata_tmp" "$source_dir/source.json"
fi

echo "version: $version"
echo "sha256: $sha256"
echo "store path: $store_path"
if $write_metadata; then
  echo "updated: $source_dir/source.json"
fi

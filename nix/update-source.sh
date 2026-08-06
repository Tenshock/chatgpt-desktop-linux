# shellcheck shell=bash

set -euo pipefail

write_metadata=false
override_compatibility=false
source_dir=

while (( $# > 0 )); do
  case "$1" in
    --write)
      write_metadata=true
      shift
      ;;
    --override)
      override_compatibility=true
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

if $override_compatibility && ! $write_metadata; then
  echo "--override requires --write" >&2
  exit 2
fi

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

  mapfile -t resolved_package < <(
    awk -f "$CHATGPT_STORE_OUTPUT_PARSER" "$work_dir/storelib.log" || true
  )
  moniker=${resolved_package[0]:-}
  url=${resolved_package[1]:-}

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

verify_args=(
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
)

runtime_sha_output=
if $override_compatibility; then
  runtime_sha_output="$work_dir/owl-runtime-sha"
fi
codex_sha_output=
if $override_compatibility; then
  codex_sha_output="$work_dir/codex-resource-sha.json"
fi
verify_args+=("$runtime_sha_output" "$codex_sha_output")

verify-chatgpt-msix "${verify_args[@]}"

verified_runtime_sha=$runtime_sha
if [[ -n $runtime_sha_output ]]; then
  verified_runtime_sha=$(< "$runtime_sha_output")
fi
verified_codex_sha=$codex_sha
verified_code_mode_host_sha=$code_mode_host_sha
verified_rg_sha=$rg_sha
if [[ -n $codex_sha_output ]]; then
  verified_codex_sha=$(jq -er .codex "$codex_sha_output")
  verified_code_mode_host_sha=$(jq -er '."codex-code-mode-host"' "$codex_sha_output")
  verified_rg_sha=$(jq -er .rg "$codex_sha_output")
fi

sha256=$(nix hash file "$download")
store_path=$(nix-store --add-fixed sha256 "$download")

if $write_metadata; then
  metadata_tmp="$work_dir/source.json"
  jq \
    --arg version "$version" \
    --arg file_name "$file_name" \
    --arg sha256 "$sha256" \
    --arg runtime_sha "$verified_runtime_sha" \
    --arg codex_sha "$verified_codex_sha" \
    --arg code_mode_host_sha "$verified_code_mode_host_sha" \
    --arg rg_sha "$verified_rg_sha" \
    '.version = $version
      | .fileName = $file_name
      | .sha256 = $sha256
      | .compatibility.owlRuntimeArchiveSha = $runtime_sha
      | .compatibility.codex.bundledX64Sha256.codex = $codex_sha
      | .compatibility.codex.bundledX64Sha256["codex-code-mode-host"] = $code_mode_host_sha
      | .compatibility.codex.bundledX64Sha256.rg = $rg_sha' \
    "$source_dir/source.json" > "$metadata_tmp"
  mv "$metadata_tmp" "$source_dir/source.json"
fi

echo "version: $version"
echo "sha256: $sha256"
echo "store path: $store_path"
if $write_metadata; then
  echo "updated: $source_dir/source.json"
fi
if $override_compatibility && [[ $verified_runtime_sha != "$runtime_sha" ]]; then
  echo "accepted Owl runtime: $verified_runtime_sha"
fi
if $override_compatibility \
  && [[ $verified_codex_sha != "$codex_sha" \
    || $verified_code_mode_host_sha != "$code_mode_host_sha" \
    || $verified_rg_sha != "$rg_sha" ]]; then
  echo "accepted bundled Codex resource hashes"
fi

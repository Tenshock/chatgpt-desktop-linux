#!/usr/bin/env bash
set -euo pipefail

msix=$1
root_2010=$2
root_2011=$3
expected_version=$4
expected_identity=${5:-OpenAI.Codex}
expected_publisher=${6:-CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B}
expected_runtime_sha=$7
expected_better_sqlite3=$8
expected_node_pty=$9
expected_node_hid=${10}
expected_serialport=${11}
expected_codex_sha=${12}
expected_code_mode_host_sha=${13}
expected_rg_sha=${14}
runtime_sha_output=${15:-}
codex_sha_output=${16:-}

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

unzip -p "$msix" AppxManifest.xml > "$work_dir/AppxManifest.xml"

xpath() {
  xmllint --xpath "string($1)" "$work_dir/AppxManifest.xml"
}

identity=$(xpath '/*[local-name()="Package"]/*[local-name()="Identity"]/@Name')
publisher=$(xpath '/*[local-name()="Package"]/*[local-name()="Identity"]/@Publisher')
architecture=$(xpath '/*[local-name()="Package"]/*[local-name()="Identity"]/@ProcessorArchitecture')
version=$(xpath '/*[local-name()="Package"]/*[local-name()="Identity"]/@Version')
display_name=$(xpath '/*[local-name()="Package"]/*[local-name()="Properties"]/*[local-name()="DisplayName"]')

[[ $identity == "$expected_identity" ]] || { echo "unexpected MSIX identity: $identity" >&2; exit 1; }
[[ $publisher == "$expected_publisher" ]] || { echo "unexpected MSIX publisher: $publisher" >&2; exit 1; }
[[ $architecture == x64 ]] || { echo "unexpected MSIX architecture: $architecture" >&2; exit 1; }
[[ $version == "$expected_version" ]] || { echo "unexpected MSIX version: $version" >&2; exit 1; }
[[ $display_name == ChatGPT ]] || { echo "unexpected MSIX display name: $display_name" >&2; exit 1; }

unzip -p "$msix" app/resources/owl-electron-app.json > "$work_dir/owl-electron-app.json"
runtime_sha=$(jq -er .runtimeArchiveSha "$work_dir/owl-electron-app.json")
[[ $runtime_sha =~ ^[0-9a-f]{64}$ ]] || {
  echo "invalid Owl runtime SHA-256: $runtime_sha" >&2
  exit 1
}
[[ -n $runtime_sha_output || $runtime_sha == "$expected_runtime_sha" ]] || {
  echo "unsupported Owl runtime: $runtime_sha" >&2
  exit 1
}

unzip -p "$msix" app/resources/app.asar > "$work_dir/app.asar"

verify_module_version() {
  local archive_path=$1
  local expected=$2
  local actual

  (
    cd "$work_dir"
    rm -f package.json
    asar extract-file app.asar "$archive_path"
    actual=$(jq -r .version package.json)
    [[ $actual == "$expected" ]] || {
      echo "unsupported $archive_path version: $actual" >&2
      exit 1
    }
  )
}

verify_module_version node_modules/better-sqlite3/package.json "$expected_better_sqlite3"
verify_module_version node_modules/node-pty/package.json "$expected_node_pty"
verify_module_version \
  node_modules/@worklouder/device-kit-oai/node_modules/node-hid/package.json \
  "$expected_node_hid"
verify_module_version \
  node_modules/@worklouder/device-kit-oai/node_modules/@serialport/bindings-cpp/package.json \
  "$expected_serialport"

verify_resource_sha() {
  local resource=$1
  local expected=$2
  local actual

  actual=$(unzip -p "$msix" "app/resources/$resource" | sha256sum | cut -d ' ' -f 1)
  [[ $actual =~ ^[0-9a-f]{64}$ ]] || {
    echo "invalid app/resources/$resource SHA-256: $actual" >&2
    exit 1
  }
  [[ -n $codex_sha_output || $actual == "$expected" ]] || {
    echo "unsupported app/resources/$resource hash: $actual" >&2
    exit 1
  }

  printf '%s\n' "$actual"
}

actual_codex_sha=$(verify_resource_sha codex "$expected_codex_sha")
actual_code_mode_host_sha=$(
  verify_resource_sha codex-code-mode-host "$expected_code_mode_host_sha"
)
actual_rg_sha=$(verify_resource_sha rg "$expected_rg_sha")

openssl x509 -inform DER -in "$root_2010" -out "$work_dir/root-2010.pem"
openssl x509 -inform DER -in "$root_2011" -out "$work_dir/root-2011.pem"

set +e
osslsigncode verify \
  -CAfile "$work_dir/root-2011.pem" \
  -TSA-CAfile "$work_dir/root-2010.pem" \
  -ignore-cdp \
  -ignore-crl \
  -in "$msix" > "$work_dir/osslsigncode.log" 2>&1
verify_status=$?
set -e

grep -Fq 'Number of verified signatures: 1' "$work_dir/osslsigncode.log"
grep -Fq 'Timestamp Server Signature verification: ok' "$work_dir/osslsigncode.log"
grep -Fq "Subject: $expected_publisher" "$work_dir/osslsigncode.log"

# OpenSSL rejects Microsoft Store's private critical extension. osslsigncode
# still verifies every APPX block hash and signature before reporting it.
if (( verify_status != 0 )); then
  grep -Fq 'Error: unhandled critical extension' "$work_dir/osslsigncode.log"
fi

osslsigncode extract-signature \
  -pem \
  -in "$msix" \
  -out "$work_dir/signature.pem" > /dev/null
openssl pkcs7 \
  -in "$work_dir/signature.pem" \
  -print_certs \
  -out "$work_dir/signature-certs.pem"
openssl verify \
  -ignore_critical \
  -no_check_time \
  -CAfile "$work_dir/root-2011.pem" \
  -untrusted "$work_dir/signature-certs.pem" \
  "$work_dir/signature-certs.pem" > /dev/null

if [[ -n $runtime_sha_output ]]; then
  printf '%s\n' "$runtime_sha" > "$runtime_sha_output"
fi
if [[ -n $codex_sha_output ]]; then
  jq -n \
    --arg codex "$actual_codex_sha" \
    --arg code_mode_host "$actual_code_mode_host_sha" \
    --arg rg "$actual_rg_sha" \
    '{
      codex: $codex,
      "codex-code-mode-host": $code_mode_host,
      rg: $rg
    }' > "$codex_sha_output"
fi

echo "verified ChatGPT MSIX $version ($architecture)"

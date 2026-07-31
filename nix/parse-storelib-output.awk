$0 ~ /OpenAI\.Codex_[0-9.]+_x64__2p2nqsd0c76g0/ &&
  match($0, /uri=https?:\/\/[^ |]+/) {
  match($0, /OpenAI\.Codex_[0-9.]+_x64__2p2nqsd0c76g0/)
  moniker = substr($0, RSTART, RLENGTH)

  match($0, /uri=https?:\/\/[^ |]+/)
  url = substr($0, RSTART + 4, RLENGTH - 4)
}

END {
  if (moniker == "" || url == "") {
    exit 1
  }

  print moniker
  print url
}

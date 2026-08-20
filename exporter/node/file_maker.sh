#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./file_maker.sh <time_sec> <max_use>

  time_sec: total time to grow the file
  max_use: target disk use % (1-99)

Example:
  ./file_maker.sh 30 80
  -> grow one unique temp file in this folder over 30 seconds until disk usage reaches 80%
EOF
}

check_num() {
  local value="${1:-}"

  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "Error: value must be integer." >&2
    return 1
  fi

  return 0
}

check_use() {
  local use="${1:-}"

  if ! [[ "$use" =~ ^[0-9]+$ ]]; then
    echo "Error: max_use must be integer." >&2
    return 1
  fi

  if (( use <= 0 || use >= 100 )); then
    echo "Error: max_use must be 1-99." >&2
    return 1
  fi

  return 0
}

new_file() {
  local dir="$1"
  local idx=1
  local file

  while :; do
    file="$dir/usage_${idx}.bin"
    if [[ ! -e "$file" ]]; then
      printf '%s\n' "$file"
      return 0
    fi
    ((idx++))
  done
}

grow_file() {
  local time_sec="$1"
  local max_use="$2"
  local dir out step use target_kib total_kib current_kib remaining_kib
  local left_slots

  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  find "$dir" -maxdepth 1 -type f -name 'usage_*.bin' -delete

  out="$(new_file "$dir")"
  : > "$out"

  read -r total_kib _ <<< "$(df -Pk "$dir" | awk 'NR==2 {print $2, $3}')"
  target_kib=$(( total_kib * max_use / 100 ))

  if (( time_sec <= 0 )); then
    echo "Error: time_sec must be positive." >&2
    rm -f "$out"
    return 1
  fi

  left_slots="$time_sec"
  while (( left_slots > 0 )); do
    current_kib="$(df -Pk "$dir" | awk 'NR==2 {print $3}')"
    remaining_kib=$(( target_kib - current_kib ))

    if (( remaining_kib <= 0 )); then
      break
    fi

    if (( left_slots == 1 )); then
      step="$remaining_kib"
    else
      step=$(( remaining_kib / left_slots ))
      if (( step <= 0 )); then
        step=1
      fi
    fi

    dd if=/dev/zero bs=1K count="$step" of="$out" conv=notrunc oflag=append status=none
    printf 'grow: %s (%s KiB)\n' "$out" "$step"

    ((left_slots--))

    if (( left_slots > 0 )); then
      sleep 1
    fi
  done

  current_kib="$(df -Pk "$dir" | awk 'NR==2 {print $3}')"
  remaining_kib=$(( target_kib - current_kib ))
  if (( remaining_kib > 0 )); then
    dd if=/dev/zero bs=1K count="$remaining_kib" of="$out" conv=notrunc oflag=append status=none
  fi

  use="$(df -P "$dir" | awk 'NR==2 {gsub("%", "", $5); print $5}')"
  printf 'done: %s%% target reached\n' "$use"
}

main() {
  local time_sec max_use

  if [[ "$#" -ne 2 ]]; then
    usage
    return 1
  fi

  time_sec="$1"
  max_use="$2"

  if ! check_num "$time_sec"; then
    usage >&2
    return 1
  fi

  if ! check_use "$max_use"; then
    usage >&2
    return 1
  fi

  grow_file "$time_sec" "$max_use"
}

main "$@"
#!/bin/bash

set -euo pipefail

set_key_repeat() {
  local repeat_rate=${1:-1}   # Default to 1 (fastest)
  local initial_delay=${2:-10} # Default to 10 (short delay)

  # Detect OS properly
  local os_type=$(uname -s)

  if [[ "$os_type" == "Darwin" ]]; then
    # macOS settings
    defaults write NSGlobalDomain KeyRepeat -int $repeat_rate
    defaults write NSGlobalDomain InitialKeyRepeat -int $initial_delay
    echo "Set keyboard repeat rate to $repeat_rate and initial delay to $initial_delay"
    echo "You may need to restart apps or log out and back in for changes to take effect"
  elif [[ "$os_type" == "Linux" ]]; then
    # Check if running GNOME
    if command -v gsettings &>/dev/null && gsettings list-schemas | grep -q "org.gnome.desktop.peripherals.keyboard"; then
      # Convert our values to GNOME-compatible values
      # For delay: lower values = shorter delay (opposite of our scale)
      # For interval: lower values = faster repeat (similar to our scale)
      local gnome_delay=$((initial_delay * 30))
      local gnome_interval=$((30 - repeat_rate * 2))   # Convert to ms (range ~10-30)

      # Ensure values are in sensible ranges
      [[ $gnome_delay -lt 50 ]] && gnome_delay=50
      [[ $gnome_delay -gt 900 ]] && gnome_delay=900
      [[ $gnome_interval -lt 10 ]] && gnome_interval=10
      [[ $gnome_interval -gt 50 ]] && gnome_interval=50

      gsettings set org.gnome.desktop.peripherals.keyboard delay $gnome_delay
      gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval $gnome_interval
      echo "Set GNOME keyboard repeat delay to ${gnome_delay}ms and interval to ${gnome_interval}ms"
    elif command -v xset &>/dev/null; then
      # Fallback to xset for non-GNOME environments
      xset r rate $((initial_delay * 15)) $((20 / repeat_rate))
      echo "Set keyboard repeat rate using xset"
    else
      echo "Neither gsettings nor xset found, cannot set keyboard repeat rate"
    fi
  else
    echo "Unsupported OS for keyboard repeat rate configuration"
  fi
}

set_key_repeat "$@"

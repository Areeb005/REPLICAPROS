#!/bin/sh
# ssl-manager launcher script with debug logging and interactive terminal reattachment
# This script checks if the ssl-manager binary is installed and ready.
# If it is, the script execs into "ssl-manager cron".
# Otherwise, it installs the binary, updates the PATH, and prompts for a token to register.
#
# Usage:
#   curl <url-to-script> | sh

set -euo pipefail

# Debug logging: prints messages if SSL_MANAGER_INSTALLER_DEBUG is set.
debug() {
  if [ -n "${SSL_MANAGER_INSTALLER_DEBUG:-}" ]; then
    printf "[DEBUG] %s\n" "$*" >&2
  fi
}

debug "Starting ssl-manager installer"

# Constants
ROOT_BIN_PATH="/opt/ssl-manager/bin/ssl-manager"
USER_BIN_PATH="$HOME/bin/ssl-manager"
BIN_URL="https://ssl-manager.s3.amazonaws.com/bin/ssl-manager"

# detect_user_type: Determines if the user is root, sudo, or non-privileged
detect_user_type() {
  if [ "$(id -u)" = "0" ]; then
    debug "Detected root user"
    echo "root"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    debug "Detected sudo user"
    echo "sudo"
  else
    debug "Detected non-privileged user"
    echo "user"
  fi
}

# set_bin_path: Sets the binary path based on user type
set_bin_path() {
  USER_TYPE=$(detect_user_type)
  if [ "$USER_TYPE" = "root" ]; then
    BIN_PATH="$ROOT_BIN_PATH"
  else
    BIN_PATH="$USER_BIN_PATH"
  fi
  debug "BIN_PATH set to $BIN_PATH"
}

# check_autossl_ready: Checks if ssl-manager is installed and reports ready status.
check_autossl_ready() {
  if command -v ssl-manager >/dev/null 2>&1; then
    debug "ssl-manager command found"
    info=$(ssl-manager info 2>/dev/null) || return 1
    debug "Retrieved ssl-manager info: $info"
    if printf "%s" "$info" | grep -q "Control panel credentials found" &&
       printf "%s" "$info" | grep -q "Vendor credentials found" &&
       printf "%s" "$info" | grep -q "Manager is ready"; then
      debug "ssl-manager is ready"
      return 0
    else
      debug "ssl-manager is not ready based on info output"
    fi
  else
    debug "ssl-manager command not found"
  fi
  return 1
}

# install_autossl: Downloads and installs the ssl-manager binary.
install_autossl() {
  USER_TYPE=$(detect_user_type)

  if [ "$USER_TYPE" = "sudo" ]; then
    debug "Using sudo to install ssl-manager"
    if command -v curl >/dev/null 2>&1; then
      debug "Using curl to download the binary"
      sudo mkdir -p "$(dirname "$ROOT_BIN_PATH")"
      sudo curl -sLo "$ROOT_BIN_PATH" "$BIN_URL"
      sudo chmod +x "$ROOT_BIN_PATH"
      sudo ln -sf "$ROOT_BIN_PATH" /usr/bin/ssl-manager
    elif command -v wget >/dev/null 2>&1; then
      debug "Using wget to download the binary"
      sudo mkdir -p "$(dirname "$ROOT_BIN_PATH")"
      sudo wget -qO "$ROOT_BIN_PATH" "$BIN_URL"
      sudo chmod +x "$ROOT_BIN_PATH"
      sudo ln -sf "$ROOT_BIN_PATH" /usr/bin/ssl-manager
    else
      printf "Error: Neither curl nor wget is installed.\n" >&2
      exit 1
    fi
    debug "Binary installed as root and symlinked to /usr/bin/ssl-manager"
  elif [ "$USER_TYPE" = "root" ]; then
    debug "Installing ssl-manager to $BIN_PATH as root"
    mkdir -p "$(dirname "$BIN_PATH")"
    if command -v curl >/dev/null 2>&1; then
      debug "Using curl to download the binary"
      curl -sLo "$BIN_PATH" "$BIN_URL"
    elif command -v wget >/dev/null 2>&1; then
      debug "Using wget to download the binary"
      wget -qO "$BIN_PATH" "$BIN_URL"
    else
      printf "Error: Neither curl nor wget is installed.\n" >&2
      exit 1
    fi
    chmod +x "$BIN_PATH"
    ln -sf "$BIN_PATH" /usr/bin/ssl-manager
    debug "Binary installed and made executable, symlinked to /usr/bin/ssl-manager"
  else
    debug "Installing ssl-manager to $BIN_PATH as regular user"
    mkdir -p "$(dirname "$BIN_PATH")"
    if command -v curl >/dev/null 2>&1; then
      debug "Using curl to download the binary"
      curl -sLo "$BIN_PATH" "$BIN_URL"
    elif command -v wget >/dev/null 2>&1; then
      debug "Using wget to download the binary"
      wget -qO "$BIN_PATH" "$BIN_URL"
    else
      printf "Error: Neither curl nor wget is installed.\n" >&2
      exit 1
    fi
    chmod +x "$BIN_PATH"
    debug "Binary installed and made executable"
  fi
}

# update_path: Adds $HOME/bin to PATH if it's not already included and if user is non-privileged.
update_path() {
  USER_TYPE=$(detect_user_type)

  if [ "$USER_TYPE" = "user" ]; then
    debug "Updating PATH to include $HOME/bin for regular user"
    if [ -f "$HOME/.bashrc" ] && ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
      echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
      debug "Added PATH update to .bashrc"
    fi
    PATH="$HOME/bin:$PATH"
  else
    debug "Skipping PATH update for $USER_TYPE user as binary is in /usr/bin"
  fi
}

# register_autossl: Prompts for a token (using /dev/tty if necessary) and registers the binary.
register_autossl() {
  debug "Prompting for registration token"
  if [ -t 0 ]; then
    printf "Please enter your token for ssl-manager registration: "
    read -r token
  elif [ -e /dev/tty ]; then
    printf "Please enter your token for ssl-manager registration: " >/dev/tty
    read -r token </dev/tty
  else
    printf "Error: No interactive terminal available for token input.\n" >&2
    exit 1
  fi
  debug "Token received, registering ssl-manager"
  USER_TYPE=$(detect_user_type)
  if [ "$USER_TYPE" = "sudo" ]; then
    debug "Using sudo to register ssl-manager"
    exec sudo ssl-manager register -t "$token"
  else
    debug "Registering ssl-manager as $USER_TYPE"
    exec ssl-manager register -t "$token"
  fi
}

main() {
  # Reattach STDIN from /dev/tty if not interactive.
  if [ ! -t 0 ] && [ -e /dev/tty ]; then
    debug "Reattaching STDIN from /dev/tty"
    exec < /dev/tty
  fi

  # Detect user type and set binary path
  set_bin_path
  debug "User type: $(detect_user_type)"

  if check_autossl_ready; then
    debug "Launching ssl-manager cron"
    USER_TYPE=$(detect_user_type)
    if [ "$USER_TYPE" = "sudo" ]; then
      debug "Using sudo to launch ssl-manager cron"
      exec sudo ssl-manager cron
    else
      debug "Launching ssl-manager cron as $USER_TYPE"
      exec ssl-manager cron
    fi
  else
    debug "ssl-manager not ready, proceeding with installation"
    install_autossl
    update_path
    register_autossl
  fi
}

main "$@"

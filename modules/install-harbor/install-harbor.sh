#!/bin/bash
# This script can be used to install Harbor and its dependencies. This script has been tested with the following
# operating systems:
#
# 1. Ubuntu 16.04

set -e

readonly DEFAULT_INSTALL_PATH="/opt/harbor"
readonly DEFAULT_HARBOR_USER="harbor"
readonly DEFAULT_DOCKER_COMPOSE_VERSION="1.19.0"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_BIN_DIR="/usr/local/bin"

readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-harbor [OPTIONS]"
  echo
  echo "This script can be used to install Harbor and its dependencies. This script has been tested with Ubuntu 16.04 only."
  echo
  echo "Options:"
  echo
  echo -e "  --version\t\tThe version of Harbor to install. Required."
  echo -e "  --path\t\tThe path where Harbor should be installed. Optional. Default: $DEFAULT_INSTALL_PATH."
  echo -e "  --user\t\tThe user who will own the Harbor install directories. Optional. Default: $DEFAULT_HARBOR_USER."
  echo -e "  --dcversion\t\tThe version of Docker Compose to install. Optional. Default: $DEFAULT_DOCKER_COMPOSE_VERSION"
  echo
  echo "Example:"
  echo
  echo "  install-harbor --version 1.4.0"
}

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local readonly arg_name="$1"
  local readonly arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function has_apt_get {
  [[ -n "$(command -v apt-get)" ]]
}

function install_dependencies {
  local readonly version="$1"

  log_info "Installing dependencies"
  
  if $(has_apt_get); then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update -y
    sudo apt-cache policy docker-ce
    sudo apt-get install -y python docker-ce curl unzip
    sudo curl -L https://github.com/docker/compose/releases/download/${version}/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  else
    log_error "Could not find apt-get. Cannot install dependencies on this OS."
    exit 1
  fi
}

function user_exists {
  local readonly username="$1"
  id "$username" >/dev/null 2>&1
}

function create_harbor_user {
  local readonly username="$1"

  if $(user_exists "$username"); then
    echo "User $username already exists. Will not create again."
  else
    log_info "Creating user named $username"
    sudo useradd "$username"
  fi
}

function create_harbor_install_paths {
  local readonly path="$1"
  local readonly username="$2"

  log_info "Creating install dirs for Harbor at $path"
  sudo mkdir -p "$path"
  sudo mkdir -p "$path/certs"
  sudo chmod 755 "$path"

  log_info "Changing ownership of $path to $username"
  sudo chown -R "$username:$username" "$path"
}

# Install steps are based on: https://github.com/vmware/harbor/blob/master/docs/installation_guide.md
function install_binaries {
  local readonly version="$1"
  local readonly path="$2"
  local readonly username="$3"
    
  local readonly url="https://storage.googleapis.com/harbor-releases/release-${version}/harbor-online-installer-v${version}.tgz"
  local readonly download_path="/tmp/harbor-online-installer-v${version}.tgz"
  local readonly harbor_dest_path="/opt/harbor"

  log_info "Downloading Harbor $version from $url to $download_path"
  curl -o "$download_path" "$url"

  log_info "Extract and move Harbor binaries to $harbor_dest_path"
  sudo tar xvf "$download_path" -C "$harbor_dest_path" --strip-components=1
  sudo chown "$username:$username" "$harbor_dest_path"
  sudo chmod a+x "$harbor_dest_path"
}

function install {
  local version=""
  local path="$DEFAULT_INSTALL_PATH"
  local user="$DEFAULT_HARBOR_USER"
  local dcversion="$DEFAULT_DOCKER_COMPOSE_VERSION"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --version)
        version="$2"
        shift
        ;;
      --path)
        path="$2"
        shift
        ;;
      --user)
        user="$2"
        shift
        ;;
      --dcversion)
        dcversion="$2"
        shift
        ;;  
      --help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--version" "$version"
  assert_not_empty "--path" "$path"
  assert_not_empty "--user" "$user"
  assert_not_empty "--dcversion" "$dcversion"

  log_info "Starting Harbor install"

  install_dependencies "$dcversion"
  create_harbor_user "$user"
  create_harbor_install_paths "$path" "$user"
  install_binaries "$version" "$path" "$user"

  log_info "Harbor install complete!"
}

install "$@"

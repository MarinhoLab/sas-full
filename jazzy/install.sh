#!/usr/bin/env bash
#
# SmartArmStack (SAS) CC BY-NC 4.0 apt bootstrap for ROS 2 jazzy.
#
# The base image `murilomarinho/sas:jazzy` already provides Ubuntu 24.04, ROS 2
# Jazzy, the `sas` LGPL packages and `dqrobotics`. Here we add the `sas`
# CC BY-NC 4.0 (noncommercial) packages on top of it, as instructed in
# https://smartarmstack.github.io/ (section "CC BY-NC 4.0 Packages").
set -Eeuo pipefail

SAS_NC_APT_URL="${SAS_NC_APT_URL:-https://marinholab.github.io/sas_debian_builder_noncommercial}"

usage() {
  cat <<'EOF'
Usage: install.sh [-n|--dry-run] [-v|--verbose] [-h|--help]

Install the SmartArmStack CC BY-NC 4.0 ROS 2 packages from the SAS apt
repository. The LGPL packages are expected to be installed already.
Safe to run as root or as a normal user (sudo is used only when needed).

Options:
  -n, --dry-run   Print the privileged steps instead of running them
  -v, --verbose   Explain what is being reused/skipped
  -h, --help      Show this help

Environment:
  SAS_NC_APT_URL    Base URL of the SAS noncommercial apt repo
EOF
}

DRY_RUN=0
VERBOSE=0
for arg in "$@"; do
  case "$arg" in
  -n | --dry-run) DRY_RUN=1 ;;
  -v | --verbose) VERBOSE=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "install.sh: unknown option: $arg (try --help)" >&2
    exit 2
    ;;
  esac
done

log() { echo "[install.sh] $*"; }
vlog() {
  if ((VERBOSE)); then echo "[install.sh] $*"; fi
}
die() {
  echo "[install.sh] ERROR: $*" >&2
  exit 1
}

# --- Privileges --------------------------------------------------------------
SUDO=()
SUDO_PREFIX=""
if [[ $(id -u) -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 ||
    die "installing needs administrator rights to write under /etc/apt. Run it as 'sudo bash install.sh'."
  SUDO=(sudo)
  SUDO_PREFIX="sudo "

  # Authenticate up front so the password is asked once, here. 'sudo -v' prompts on
  # the controlling terminal, which survives 'curl ... | bash', and fails at once
  # when there is no terminal.
  if ! ((DRY_RUN)) && ! sudo -n true 2>/dev/null && ! sudo -v; then
    die "could not get sudo credentials. Run 'sudo bash install.sh', or cache them with 'sudo -v' first."
  fi
fi

as_root() {
  if ((DRY_RUN)); then
    echo "[install.sh] (dry-run) ${SUDO_PREFIX}$*"
  else
    "${SUDO[@]}" "$@"
  fi
}

apt_run() {
  if ((DRY_RUN)); then
    echo "[install.sh] (dry-run) ${SUDO_PREFIX}apt-get $*"
  else
    "${SUDO[@]}" apt-get "$@"
  fi
}

# --- Prerequisites -----------------------------------------------------------
missing=()
for tool in curl gpg dpkg apt-cache; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
((${#missing[@]} == 0)) ||
  die "missing required tool(s): ${missing[*]}. Install them first, e.g.: ${SUDO_PREFIX}apt-get install -y curl gnupg dpkg apt"

if [[ ! -t 0 && -z "${DEBIAN_FRONTEND:-}" ]]; then
  export DEBIAN_FRONTEND=noninteractive
  vlog "no tty: DEBIAN_FRONTEND=noninteractive"
fi

# --- Detect where we are -----------------------------------------------------
distro=jazzy
arch="$(dpkg --print-architecture)"
codename="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release 2>/dev/null || true)"
[[ -n "$codename" ]] || codename="$(lsb_release -cs 2>/dev/null || true)"
# The noncommercial repo is a flat './' one publishing noble debs only, so the
# codename is only reported here, it never goes into the source line.
log "user=$(id -un) root=$(if [[ $(id -u) -eq 0 ]]; then echo yes; else echo no; fi) | ros=$distro | ubuntu=${codename:-unknown} | arch=$arch"

# --- Apt sources -------------------------------------------------------------
nc_url="$SAS_NC_APT_URL"
nc_keyring=/etc/apt/keyrings/smartarmstack_cc_by_nc.gpg

# Prefer the file an earlier run already wrote, so that two entries for the same
# URI cannot end up with different Signed-By values and break apt-get update.
existing_source_for() {
  local host="${1#*://}"
  grep -rlF "${host%/}" /etc/apt/sources.list.d/*.list 2>/dev/null | head -n 1 || true
}
nc_source="$(existing_source_for "$nc_url")"
nc_source="${nc_source:-/etc/apt/sources.list.d/smartarmstack_cc_by_nc.list}"
if [[ -f "$nc_source" ]]; then vlog "reusing the existing apt source file $nc_source"; fi

# Overwriting a file that is already correct would invalidate apt's package lists.
write_if_changed() { # $1 = file to write from, $2 = where to write it
  if ((!DRY_RUN)) && as_root cmp -s "$2" "$1" 2>/dev/null; then
    vlog "$(basename "$2") already up to date"
  else
    as_root install -D -m 0644 "$1" "$2"
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --compressed "$nc_url/KEY.gpg" | gpg --dearmor >"$tmp/nc.key" ||
  die "could not download/dearmor the SAS signing key from $nc_url/KEY.gpg"
printf 'deb [arch=%s signed-by=%s] %s ./\n' "$arch" "$nc_keyring" "$nc_url" >"$tmp/nc.list"

write_if_changed "$tmp/nc.key" "$nc_keyring"
write_if_changed "$tmp/nc.list" "$nc_source"

apt_run update -q || die "apt-get update failed: check the network and the apt source above"

# --- Packages ----------------------------------------------------------------
# The CC BY-NC 4.0 packages this image adds on top of the LGPL base image.
packages=(
  "ros-$distro-sas-operator-side-receiver"
  "ros-$distro-sas-patient-side-manager"
  "ros-$distro-sas-robot-kinematics-constrained-multiarm"
)

if ((DRY_RUN)); then
  log "dry-run: would install ${#packages[@]} package(s): ${packages[*]}"
else
  # Fail here, naming the repo, rather than letting apt report an unknown package.
  unavailable=()
  for package in "${packages[@]}"; do
    apt-cache show "$package" >/dev/null 2>&1 || unavailable+=("$package")
  done
  ((${#unavailable[@]} == 0)) ||
    die "not in any configured apt source: ${unavailable[*]}. Is '$distro' published under $nc_url?"

  log "installing ${#packages[@]} package(s): ${packages[*]}"
  apt_run install -y "${packages[@]}" ||
    die "package installation failed: check the SAS noncommercial apt source above"

  # Leave no apt state behind: this runs inside a docker build layer.
  apt_run autoremove -y
  apt_run clean
  # The directory, not a glob: apt recreates it on the next update, and an
  # unexpanded glob would be resolved by the calling user when sudo is needed.
  as_root rm -rf /var/lib/apt/lists

  log "done: SAS CC BY-NC 4.0 packages installed for ROS 2 '$distro'."
fi

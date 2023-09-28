#!/bin/bash
# Script install Sunteco Metrics Agent of service Sun Monitor. 
# 
# checking OS ----> linux, windows detech and sum string to download version build adap.

set -e 

function parse_args() {
  #BINDIR is ./bin unless set be ENV
  # over-ridden by flag below

  BINDIR=${BINDIR:-/usr/bin}
  while getopts "b:dh?x" arg; do
    case "$arg" in
      b) BINDIR="$OPTARG" ;;
      d) log_set_priority 10 ;;
      h | \?) usage "$0" ;;
      x) set -x ;;
    esac
  done
  shift $((OPTIND - 1))
  TAG=$1
}

function execute() {
    tmpdir=$(mktemp -d)
    log_info "downloading files into ${tmpdir}"
    http_download "${tmpdir}/${TARBALL}" "${TARBALL_URL}"
    http_download "${tmpdir}/${CHECKSUM}" "${CHECKSUM_URL}"
    hash_sha256_verify "${tmpdir}/${TARBALL}" "${tmpdir}/${CHECKSUM}"
    srcdir="${tmpdir}"
    (cd "${tmpdir}" && untar "${TARBALL}")
    test ! -d "${BINDIR}" && install -d "${BINDIR}"
    for binexe in $BINARIES; do
        if [ "$OS" = "windows" ]; then
          binexe="${binexe}.exe"
        fi
        install "${srcdir}/${binexe}" "${BINDIR}/"
        log_info "installed ${BINDIR}/${binexe}"
    done
    rm -rf "${tmpdir}"
}
function sun_releases() {
  url=$1
#   version=$2
#   test -z "$version" && version="latest"
  fileurl="$url"
  json=$(http_copy "$fileurl" )
  version=$(echo "$json" )
  test -z "$json" && return 1
#   version=$(echo "$json" | tr -s '\n' ' ' | sed 's/.*"tag_name":"//' | sed 's/".*//')
  version=$(echo "$json" )
#   test -z "$version" && return 1
#   echo "$version"
}
#  get tag version of sunteco agent
function tag_to_version() {
    if [ -z "${TAG}" ]; then
        log_info "checking GitHub for latest tag"
    else
        log_info "checking GitHub for tag '${TAG}'"
    fi
    printf "$TARBALL_URL"
    REALTAG=$(sun_releases "$TARBALL_URL") && true
    if test -z "$REALTAG"; then
        log_crit "unable to find '${TAG}' - use 'latest' or see  for details"
        exit 1
    fi
    # if version starts with 'v', remove it
    # fix test versions support
    # TAG="v1.0.0"
    TAG="$REALTAG"
    VERSION=${TAG#v}
}

function adjust_format() {
  # change format (tar.gz or zip) based on OS
  case ${OS} in
    windows) FORMAT=zip ;;
  esac
  true
}
function adjust_os() {
  # adjust archive name based on OS
  case ${OS} in
    386) OS=i386 ;;
    amd64) OS=x86_64 ;;
    darwin) OS=Darwin ;;
    linux) OS=Linux ;;
    windows) OS=Windows ;;
  esac
  true
}
function adjust_arch() {
  # adjust archive name based on ARCH
  case ${ARCH} in
    386) ARCH=i386 ;;
    amd64) ARCH=x86_64 ;;
    darwin) ARCH=Darwin ;;
    linux) ARCH=Linux ;;
    windows) ARCH=Windows ;;
  esac
  true
}
ETCDIR=$(echo "/etc/sunteco_agent")
COLLECTOR_DIR=${ETCDIR}/collector.d
SYSTEM_FILE="/lib/systemd/system/sunteco-agent.service"

function config() {
    if [ -v $SECRET_KEY ]; then
        printf "\033[34m\n* Not found variables SECRET_KEY install process is exit! \033[34m\n*"
        printf "\033[34m\n* Please active service Sunteco Monitor and get secret key on dashboard services. \033[34m\n*"
        exit 1
    fi
    if [ ! -d  $ETCDIR ]; then
        printf "\033[34m\n* not found directory configurations. $ETCDIR \033[34m\n*"
        $sudo_cmd mkdir "$ETCDIR"
        $sudo_cmd mkdir "$COLLECTOR_DIR"
    else
        if [ ! -d $COLLECTOR_DIR ]; then
            printf "\033[34m\n* not found directory collectors configurations. $COLLECTOR_DIR \033[34m\n*"
            $sudo_cmd mkdir "$COLLECTOR_DIR"            
        fi
    fi
    if [  ! -e $SYSTEM_FILE ]; then
        printf "\033[34m\n* Keeping systemd service file $SYSTEM_FILE \033[34m\n*"
    else
        cat $SYSTEM_FILE <<EOF
[Unit]
Description=Sunteco Metrics Agent (SMA)
After=network.target


[Service]
Type=simple
User=root
Restart=always
ExecStart=/usr/bin/sun-agent
StartLimitInterval=10
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF
    fi
    $sudo_cmd chown -r root:root $ETCDIR
    $sudo_cmd chmod 0644 $CONF

}
function create_service() {
    if [ ! -e $SYSTEM_FILE ]; then
        printf "\033[34m\n* Keeping systemd service file $SYSTEM_FILE \033[34m\n*"
        
    fi
}
cat /dev/null <<EOF
-----------------------------------------------
portable posix shell functions
-----------------------------------------------
EOF


function is_command() {
    command -v "$1" >/dev/null
}
function echoerr() {
    echo "$@" 1>&2
}
function log_prefix() {
    echo "$0"
}
_logp=6
function log_set_priority() {
  _logp="$1"
}
function log_priority() {
    if test -z "$1"; then
        echo "$_logp"
        return
    fi
    [ "$1" -le "$_logp" ]
}


function log_tag() {
    case $1 in
        0) echo "emerg" ;;
        1) echo "alert" ;;
        2) echo "crit" ;;
        3) echo "err" ;;
        4) echo "warning" ;;
        5) echo "notice" ;;
        6) echo "info" ;;
        *) echo "$1" ;;
    esac
}
function log_info() {
    log_priority 6 || return 0
    echoerr "$(log_prefix)" "$(log_tag 6)" "$@"
}
function log_err() {
    log_priority 3 || return 0
    echoerr "$(log_prefix)" "$(log_tag 3)" "$@"
}
function log_crit() {
    log_priority 2 || return 0
    echoerr "$(log_prefix)" "$(log_tag 2)" "$@"
}

function arch_check() {
    arch=$(uname -m)
    case "$arch" in 
        x86_64) arch="amd64";;
        x86)    arch="386";;
        i686) arch="386";;
        i386) arch="386";;
        aarch64) arch="arm64";;
        armv5*) arch="armv5";;
        armv6*) arch="armv6";;
        armv7*) arch="armv7";;
    esac
    echo ${arch}
}
function uname_os() {
  os=$(uname -s | tr '[:upper:]' '[:lower:]')

  # fixed up for https://github.com/client9/shlib/issues/3
  case "$os" in
    msys*) os="windows" ;;
    mingw*) os="windows" ;;
    cygwin*) os="windows" ;;
    win*) os="windows" ;; # for windows busybox and like # https://frippery.org/busybox/
  esac

  # other fixups here
  echo "$os"
}
function uname_os_check() {
  os=$(uname_os)
  case "$os" in
    darwin) return 0 ;;
    dragonfly) return 0 ;;
    freebsd) return 0 ;;
    linux) return 0 ;;
    android) return 0 ;;
    nacl) return 0 ;;
    netbsd) return 0 ;;
    openbsd) return 0 ;;
    plan9) return 0 ;;
    solaris) return 0 ;;
    windows) return 0 ;;
  esac
  log_crit "uname_os_check '$(uname -s)' got converted to '$os' which is not a GOOS value. Please file bug at https://github.com/client9/shlib"
  return 1
}
function get_binaries() {
  case "$PLATFORM" in
    linux/386) BINARIES="sun-agent" ;;
    linux/amd64) BINARIES="sun-agent" ;;
    linux/arm64) BINARIES="sun-agent" ;;
    linux/armv6) BINARIES="sun-agent" ;;
    windows/386) BINARIES="sun-agent" ;;
    windows/amd64) BINARIES="sun-agent" ;;
    windows/arm64) BINARIES="sun-agent" ;;
    windows/armv6) BINARIES="sun-agent" ;;
    *)
      log_crit "platform $PLATFORM is not supported.  Make sure this script is up-to-date and file request at https://github.com/${PREFIX}/issues/new"
      exit 1
      ;;
  esac
}
function untar() {
    tarball=$1
    case "${tarball}" in
        *.tar.gz | *.tgz) tar --no-same-owner -xzf "${tarball}" ;;
        *.tar) tar --no-same-owner -xf "${tarball}" ;;
        *.zip) unzip "${tarball}" ;;
        *)
            log_err "untar unknown archive format for ${tarball}"
            return 1
            ;;
    esac
}
function http_download_curl() {
    local_file=$1
    source_url=$2
    header=$3
    if [ -z "$header" ]; then
        code=$(curl -w '%{http_code}' -sL -o "$local_file" "$source_url")
    else
        code=$(curl -w '%{http_code}' -sL -H "$header" -o "$local_file" "$source_url")
    fi
    if [ "$code" != "200" ]; then
        log_info "http_download_curl received HTTP status $code"
        return 1
    fi
    return 0
}
function http_download_wget() {
    local_file=$1
    source_url=$2
    header=$3
    if [ -z "$header" ]; then
        wget -q -O "$local_file" "$source_url"
    else
        wget -q --header "$header" -O "$local_file" "$source_url"
    fi
}
function http_download() {
    log_info "http_download $2"
    if is_command curl; then
        http_download_curl "$@"
        return
    elif is_command wget; then
        http_download_wget "$@"
        return
    fi
    log_crit "http_download unable to find wget or curl"
    return 1
}
function http_copy() {
  tmp=$(mktemp)
  http_download "${tmp}" "$1" "$2" || return 1
  body=$(cat "$tmp")
  rm -f "${tmp}"
  echo "$body"
}
function hash_sha256() {
    TARGET=${1:-/dev/stdin}
    if is_command gsha256sum; then
        hash=$(gsha256sum "$TARGET") || return 1
        echo "$hash" | cut -d ' ' -f 1
    elif is_command sha256sum; then
        hash=$(sha256sum "$TARGET") || return 1
        echo "$hash" | cut -d ' ' -f 1
    elif is_command shasum; then
        hash=$(shasum -a 256 "$TARGET" 2>/dev/null) || return 1
        echo "$hash" | cut -d ' ' -f 1
    elif is_command openssl; then
        hash=$(openssl -dst openssl dgst -sha256 "$TARGET") || return 1
        echo "$hash" | cut -d ' ' -f a
    else
        log_crit "hash_sha256 unable to find command to compute sha-256 hash"
        return 1
    fi
}
function hash_sha256_verify() {
    TARGET=$1
    checksums=$2
    log_info "hash_sha256_verify checksum $checksums for $TARGET"
    if [ -z "$checksums" ]; then
        log_err "hash_sha256_verify checksum file not specified in arg2"
        return 1
    fi
    BASENAME=${TARGET##*/}
    want=$(grep "${BASENAME}" "${checksums}" 2>/dev/null | tr '\t' ' ' | cut -d ' ' -f 1)
    if [ -z "$want" ]; then
        log_err "hash_sha256_verify unable to find checksum for '${TARGET}' in '${checksums}'"
        return 1
    fi
    got=$(hash_sha256 "$TARGET")
    if [ "$want" != "$got" ]; then
        log_err "hash_sha256_verify checksum for '$TARGET' did not verify ${want} vs $got"
        return 1
    fi
}
cat /dev/null <<EOF
------------------------------------------------------------------------
End of functions
------------------------------------------------------------------------
EOF
PROJECT_NAME="sunteco-agent"
# OWNER=SUNTECO
# REPO="SUNTECO-AGENT"
BINARY="sun_agent"
FORMAT=tar.gz
OS=$(uname_os)
ARCH=$(arch_check)
PREFIX="${OWNER}/${REPO}"
function log_prefix() {
    echo "${PREFIX}"
}
PLATFORM="${OS}/${ARCH}"

BUCKETNAME="sunteco-agent"
URL_DOWNLOAD=https://s3.sunteco.app/$PROJECT_NAME/releases

log_info "found version: ${VERSION} FOR ${TAG}/${OS}/${ARCH}"
NAME=${PROJECT_NAME}_${OS}_${ARCH}
TARBALL=${NAME}.${FORMAT}
TARBALL_URL=${URL_DOWNLOAD}/${TAG}/${TARBALL}
CHECKSUM=${BINARY}_checksums.txt
CHECKSUM_URL=${URL_DOWNLOAD}/$TAG/${CHECKSUM}

uname_os_check "$OS"

arch_check "$ARCH"

parse_args "$@"

get_binaries

tag_to_version

adjust_format

adjust_os

adjust_arch

# log_info "found version: ${VERSION} FOR ${TAG}/${OS}/${ARCH}"
# NAME=${PROJECT_NAME}_${OS}_${ARCH}
# TARBALL=${NAME}.${FORMAT}
# TARBALL_URL=${URL_DOWNLOAD}/${TAG}/${TARBALL}
# CHECKSUM=${BINARY}_checksums.txt
# CHECKSUM_URL=${URL_DOWNLOAD}/$TAG/${CHECKSUM}

execute

if [ "$(echo "$UID")" = "0" ]; then
    sudo_cmd=''
else
    sudo_cmd='sudo'
fi


init_config

config

create_service

final
#!/bin/bash

usage() {
    cat <<EOF
usage: [-d/--download] [-n/--no-download] [-o/--download-only] version

    -d, --download          force download even if version is already downloaded
    -n, --no-download       exit early if version is not cached
    -o, --download-only     don't install, only download

downloads and installs a given version of roundup.

NOTE:
    this does NOT perform update/migration this is simply used to install a
    version of roundup correctly.

example usage:

    roundup-install 2.0.0
    roundup-install 2.1.0

EOF
}

fatal() {
    echo "error: $@" >&2
    usage
    exit 1
}

RU_HOME='/home/roundup'
RU_LOCAL="$RU_HOME/.local"
RU_VERSIONS="$RU_HOME/versions"
PY_V="$(python3 --version | sed "s|^.* \(3\.[0-9]\+\).*|\1|")"

is_cached() {
    ver="$1"
    [ -d "$RU_VERSIONS/roundup-$ver" ] || [ -f "$RU_VERSIONS/roundup-$ver.tar.gz" ] 
}

download_ver()  {
    ver="$1"
    if [ ! -d "$RU_VERSIONS" ]; then
        su - roundup -c "mkdir '$RU_VERSIONS'"
    fi
    cd "$RU_VERSIONS"
    su - roundup -c "cd '$RU_VERSIONS'; pip download 'roundup==$ver'"
    cd -
}

install_ver() {
    ver="$1"
    if [ ! -d "$RU_VERSIONS/roundup-$ver" ]; then
        su - roundup -c "cd '$RU_VERSIONS'; tar -xvf 'roundup-$ver.tar.gz'"
    fi
    
    su - roundup -c "cd '$RU_VERSIONS/roundup-$ver';\
python3 setup.py install --prefix='$RU_LOCAL'"
    cd -

    LOCAL=/usr/local
    TARGETS="/bin/roundup-admin /bin/roundup-gettext /bin/roundup-mailgw /share/roundup"
    for target in $TARGETS; do
        ln -sf "${RU_LOCAL}${target}" "${LOCAL}${target}"
    done
    TARGET="lib/python${PY_V}"
    ln -sf "${RU_LOCAL}/${TARGET}/site-packages/roundup" \
        "${LOCAL}/${TARGET}/dist-packages/roundup"
    ln -sf "${RU_LOCAL}/${TARGET}/site-packages/roundup-${ver}.dist-info" \
        "${LOCAL}/${TARGET}/dist-packages/roundup-${ver}.dist-info"
    ln -sf "${RU_LOCAL}/share/doc/roundup" "/var/www/docs"
    ln -sf "${RU_LOCAL}/share/man/man1" "/usr/local/share/man/man1"
}

POSITIONAL=()
DOWNLOAD=
INSTALL=y
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--download)
            DOWNLOAD=y
            shift
            ;;
        -n|--no-download)
            DOWNLOAD=n
            shift
            ;;
        -o|--download-only)
            INSTALL=
            shift
            ;;
        -h|--help)
            usage
            exit
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ "${#POSITIONAL[@]}" < 1 ]]; then
    fatal "version is required"
elif [[ "${#POSITIONAL[@]}" > 1 ]]; then
    fatal "unknown extra args provided: ${POSITIONAL[@]:1}"
fi
VER="${POSITIONAL[0]}"


if ! is_cached "$VER"; then
    if [ "$DOWNLOAD" == 'n' ]; then
        fatal "\"$VER\" not stored locally and -n/--no-download set"
    else
        download_ver "$VER"
    fi
elif [ "$DOWNOAD" == 'y' ]; then
    download_ver "$VER"
fi

if [ -n "$INSTALL" ]; then
    install_ver "$VER"
fi

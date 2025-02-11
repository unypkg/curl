#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

apt install -y autopoint

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install libpsl libidn2 libunistring nghttp2 openssl/1.1.1w

#pip3_bin=(/uny/pkg/python/*/bin/pip3)
#"${pip3_bin[0]}" install meson

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="curl"
pkggit="https://github.com/curl/curl.git curl-*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "curl-[0-9_]*$" | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "curl-[0-9_].*" | sed -e "s|curl-||" -e "s|_|.|g")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo

cd "$pkgname" || exit
autoreconf -fi
cd /uny/sources || exit

version_details
archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/git/unypkg/fn

pkgname="curl"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths

####################################################
### Start of individual build script

#unset LD_RUN_PATH

./configure --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --disable-static                        \
    --with-openssl                          \
    --with-libidn2                          \
    --enable-threaded-resolver              \
    --with-ca-path=/etc/uny/ssl/certs

make -j"$(nproc)"

make -j"$(nproc)" install

rm -rf docs/examples/.deps &&
find docs \( -name Makefile\* -o  \
             -name \*.1       -o  \
             -name \*.3       -o  \
             -name CMakeLists.txt \) -delete &&
cp -v -R docs -T /uny/pkg/"$pkgname"/"$pkgver"/share/doc/curl

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg

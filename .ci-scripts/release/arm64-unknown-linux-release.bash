#!/bin/bash

# arm64-unknown-linux release:
#
# - Builds release package
# - Uploads to the GitHub Release
#
# Tools required in the environment that runs this:
#
# - bash
# - corral
# - GNU make
# - gzip
# - ponyc (musl based version)
# - python3
# - tar

set -o errexit

# Pull in shared configuration specific to this repo
base=$(dirname "$0")
# shellcheck source=.ci-scripts/release/config.bash
source "${base}/config.bash"

# Verify ENV is set up correctly
# We validate all that need to be set in case, in an absolute emergency,
# we need to run this by hand. Otherwise the GitHub actions environment should
# provide all of these if properly configured
if [[ -z "${RELEASE_TOKEN}" ]]; then
  echo -e "\e[31mRELEASE_TOKEN needs to be set for the GitHub Release upload."
  echo -e "Exiting.\e[0m"
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY}" ]]; then
  echo -e "\e[31mName of this repository needs to be set in GITHUB_REPOSITORY."
  echo -e "\e[31mShould be in the form OWNER/REPO, for example:"
  echo -e "\e[31m     ponylang/cloudsmith-uploader"
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

if [[ -z "${APPLICATION_NAME}" ]]; then
  echo -e "\e[31mAPPLICATION_NAME needs to be set."
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

if [[ -z "${APPLICATION_SUMMARY}" ]]; then
  echo -e "\e[31mAPPLICATION_SUMMARY needs to be set."
  echo -e "\e[31mIt's a short description of the application that will appear in Cloudsmith."
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

# no unset variables allowed from here on out
# allow above so we can display nice error messages for expected unset variables
set -o nounset

# Compiler target parameters
ARCH=arm64
CPU=generic

# Triple construction
VENDOR=unknown
OS=linux
TRIPLE=${ARCH}-${VENDOR}-${OS}

# Build parameters
BUILD_PREFIX=$(mktemp -d)
APPLICATION_VERSION=$(cat VERSION)
BUILD_DIR=${BUILD_PREFIX}/${APPLICATION_VERSION}

# Asset information
PACKAGE_DIR=$(mktemp -d)
PACKAGE=${APPLICATION_NAME}-${TRIPLE}

# Asset file
ASSET_FILE=${PACKAGE_DIR}/${PACKAGE}.tar.gz

# Build application installation
echo -e "\e[34mBuilding ${APPLICATION_NAME}...\e[0m"
make install prefix="${BUILD_DIR}" arch=${CPU} \
  version="${APPLICATION_VERSION}" static=true

# Package it all up
echo -e "\e[34mCreating .tar.gz of ${APPLICATION_NAME}...\e[0m"
pushd "${BUILD_PREFIX}" || exit 1
tar -cvzf "${ASSET_FILE}" -- *
popd || exit 1

echo -e "\e[34mUploading package to GitHub Release...\e[0m"
python3 "${base}/github_release.py" upload "${APPLICATION_VERSION}" "${ASSET_FILE}"

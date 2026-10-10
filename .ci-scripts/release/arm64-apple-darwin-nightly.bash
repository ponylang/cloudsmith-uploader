#!/bin/bash

# arm64-apple-darwin nightly:
#
# - Builds nightly package
# - Uploads to GHCR
#
# Tools required in the environment that runs this:
#
# - bash
# - GNU coreutils
# - GNU gzip
# - GNU make
# - ponyc
# - corral
# - python3
# - GNU tar

# add hard way installed ponyc, corral to our PATH
export PATH="/tmp/corral/bin:/tmp/ponyc/bin/:$PATH"

set -o errexit

# Pull in shared configuration specific to this repo
base=$(dirname "$0")
# shellcheck source=.ci-scripts/release/config.bash
source "${base}/config.bash"

# Verify ENV is set up correctly
# We validate all that need to be set in case, in an absolute emergency,
# we need to run this by hand. Otherwise the GitHub actions environment should
# provide all of these if properly configured
if [[ -z "${GITHUB_REPOSITORY}" ]]; then
  echo -e "\e[31mName of this repository needs to be set in GITHUB_REPOSITORY."
  echo -e "\e[31mShould be in the form OWNER/REPO, for example:"
  echo -e "\e[31m     ponylang/cloudsmith-uploader"
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo -e "\e[31mGITHUB_TOKEN needs to be set for GHCR publishing."
  echo -e "Exiting.\e[0m"
  exit 1
fi

if [[ -z "${APPLICATION_NAME}" ]]; then
  echo -e "\e[31mAPPLICATION_NAME needs to be set."
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

# no unset variables allowed from here on out
set -o nounset

TODAY=$(date +%Y%m%d)

# Compiler target parameters
ARCH=arm64
CPU=apple-m1

# Triple construction
VENDOR=apple
OS=darwin
TRIPLE=${ARCH}-${VENDOR}-${OS}

# Build parameters
BUILD_PREFIX=$(mktemp -d)
APPLICATION_VERSION="nightly-${TODAY}"
BUILD_DIR=${BUILD_PREFIX}/${APPLICATION_VERSION}

# Asset information
PACKAGE_DIR=$(mktemp -d)
PACKAGE=${APPLICATION_NAME}-${TRIPLE}
ASSET_FILE=${PACKAGE_DIR}/${PACKAGE}.tar.gz

# Build application installation
echo -e "\e[34mBuilding ${APPLICATION_NAME}...\e[0m"
make install prefix="${BUILD_DIR}" arch=${CPU} \
  version="${APPLICATION_VERSION}"

# Package it all up
echo -e "\e[34mCreating .tar.gz of ${APPLICATION_NAME}...\e[0m"
pushd "${BUILD_PREFIX}" || exit 1
tar -cvzf "${ASSET_FILE}" -- *
popd || exit 1

# Publish to GHCR as an OCI artifact.
echo -e "\e[34mUploading package to GHCR...\e[0m"
python3 "${base}/ghcr_nightly.py" push cloudsmith-uploader "${TRIPLE}" \
  "${TODAY}" "${ASSET_FILE}"

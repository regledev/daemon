#!/bin/bash

# V0 install script for regle daemon
# based on https://raw.githubusercontent.com/buildkite/agent/main/install.sh

# steps
# 0. setup local dir etc.; check arch
# 1. dowload right arch bin
# 2. download right install sh
# 3.

set -e

# COMMAND="bash -c \"\`curl -sL https://raw.githubusercontent.com/regledv/daemon/master/script/install.sh\`\""

SYSTEM=$(uname -s | awk '{print tolower($0)}')
MACHINE=$(uname -m | awk '{print tolower($0)}')

if [[ ($SYSTEM == *"mac os x"*) || ($SYSTEM == *darwin*) ]]; then
  PLATFORM="darwin"
elif [[ ($SYSTEM == *"freebsd"*) ]]; then
  PLATFORM="freebsd"
else
  PLATFORM="linux"
fi

if [ -n "$REGLE_INSTALL_ARCH" ]; then
  ARCH="$REGLE_INSTALL_ARCH"
  echo "Using explicit arch '$ARCH'"
else
  case $MACHINE in
    *amd64*)   ARCH="amd64"   ;;
    *x86_64*)
      ARCH="amd64"

      # On Apple Silicon Macs, the architecture reported by `uname` depends on
      # the architecture of the shell, which is in turn influenced by the
      # *terminal*, as *child processes prefer their parents' architecture*.
      #
      # This means that for Terminal.app with the default shell it will be
      # arm64, but x86_64 for people using (pre-3.4.0 builds of) iTerm2 or
      # x86_64 shells.
      #
      # Based on logic in Homebrew: https://github.com/Homebrew/brew/pull/7995
      if [[ "$PLATFORM" == "darwin" && "$(/usr/sbin/sysctl -n hw.optional.arm64 2> /dev/null)" == "1" ]]; then
        ARCH="arm64"
      fi
      ;;
    *arm64*)
      ARCH="arm64"
      ;;
    *armv8*)   ARCH="arm64"   ;;
    *armv7*)   ARCH="armhf"   ;;
    *armv6l*)  ARCH="arm"     ;;
    *armv6*)   ARCH="armhf"   ;;
    *arm*)     ARCH="arm"     ;;
    *ppc64le*) ARCH="ppc64le" ;;
    *aarch64*) ARCH="arm64"   ;;
    *mips64*) ARCH="mips64le" ;;
    *s390x*)   ARCH="s390x"   ;;
    *)
      ARCH="386"
      echo -e "\n\033[36mWe don't recognise the $MACHINE architecture; falling back to $ARCH\033[0m"
      ;;
  esac
fi

RELEASE_INFO_URL="https://raw.githubusercontent.com/regledev/daemon/main/RELEASE"

if command -v wget >/dev/null; then
  LATEST_RELEASE=$(wget -qO- "$RELEASE_INFO_URL")
else
  LATEST_RELEASE=$(curl -s "$RELEASE_INFO_URL")
fi

VERSION=$LATEST_RELEASE
DOWNLOAD_FILENAME="regle_daemon_${VERSION}_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/regledev/daemon/releases/download/${VERSION}/${DOWNLOAD_FILENAME}"

function download-regle {
  REGLE_DOWNLOAD_TMP_FILE="/tmp/regle-daemon-download-$$.txt"

  if command -v wget >/dev/null
  then
    wget "$1" -O "$2" 2> $REGLE_DOWNLOAD_TMP_FILE || REGLE_DOWNLOAD_EXIT_STATUS=$?
  else
    curl -L -o "$2" "$1" 2> $REGLE_DOWNLOAD_TMP_FILE || REGLE_DOWNLOAD_EXIT_STATUS=$?
  fi

  if [[ $REGLE_DOWNLOAD_EXIT_STATUS -ne 0 ]]; then
    echo -e "\033[31mFailed to download file: $1\033[0m\n"

    cat $REGLE_DOWNLOAD_TMP_FILE
    exit $REGLE_DOWNLOAD_EXIT_STATUS
  fi
}

echo -e "Installing Version: \033[35mv$VERSION\033[0m"

# Default the destination folder
: ${DESTINATION:="$HOME/.regle-daemon"}

mkdir -p "$DESTINATION"

if [[ ! -w "$DESTINATION" ]]; then
  echo -e "\n\033[31mUnable to write to destination \`$DESTINATION\`\n\nYou can change the destination by running:\n\nDESTINATION=/my/path $COMMAND\033[0m\n"
  exit 1
fi

echo -e "Destination: \033[35m$DESTINATION\033[0m"

echo -e "Downloading $DOWNLOAD_URL"

# Create a temporary folder to download the binary to
INSTALL_TMP=/tmp/regle-daemon-install-$$
mkdir -p $INSTALL_TMP

# If the file already exists in a folder called releases. This is useful for
# local testing of this file.
if [[ -e releases/$DOWNLOAD ]]; then
  echo "Using existing release: releases/$DOWNLOAD_FILENAME"
  cp releases/"$DOWNLOAD_FILENAME" $INSTALL_TMP
else
  download-regle "$DOWNLOAD_URL" "$INSTALL_TMP/$DOWNLOAD_FILENAME"
fi

# Extract the download to a tmp folder inside the $DESTINATION
# folder
tar -C "$INSTALL_TMP" -zxf "$INSTALL_TMP"/"$DOWNLOAD_FILENAME"

# Move the binary into a bin folder
mkdir -p "$DESTINATION"/bin
mv $INSTALL_TMP/regle-daemon "$DESTINATION"/bin
chmod +x "$DESTINATION"/bin/regle-daemon

# Set their token for them
if [[ -n $REGLE_API_KEY ]]; then
  echo $REGLE_API_KEY > $DESTINATION/key
else
echo -e "\n\033[36mDon't forget to create \`key\` file with your API token! You can create one on \"API\" page in Regle\033[0m"
fi

echo -e "\n\033[32mSuccessfully installed to $DESTINATION\033[0m

You can now start the daemon!

  $DESTINATION/bin/regle-daemon

"

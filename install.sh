#!/bin/sh

TMP_NAME="./$(head -n 1 -c 32 /dev/urandom | tr -dc 'a-zA-Z0-9'| fold -w 32)"
PRERELEASE=false
PRERELEASE_FLAG=""
if [ "$1" = "--prerelease" ]; then
    PRERELEASE=true
    PRERELEASE_FLAG="--prerelease"
fi

if which curl >/dev/null; then
    if curl --help  2>&1 | grep "--progress-bar" >/dev/null 2>&1; then 
        PROGRESS="--progress-bar"
    fi

    set -- curl -L $PROGRESS -o "$TMP_NAME"
    if [ "$PRERELEASE" = true ]; then
        LATEST=$(curl -sL https://api.github.com/repos/alis-is/ami/releases | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | head -n 1 | tr -d '[:space:]')
    else
        LATEST=$(curl -sL https://api.github.com/repos/alis-is/ami/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | tr -d '[:space:]')
    fi
else
    if wget --help  2>&1 | grep "--show-progress" >/dev/null 2>&1; then 
        PROGRESS="--show-progress"
    fi
    set -- wget -q $PROGRESS -O "$TMP_NAME"
    if [ "$PRERELEASE" = true ]; then
        LATEST=$(wget -qO- https://api.github.com/repos/alis-is/ami/releases | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | head -n 1 | tr -d '[:space:]')
    else
        LATEST=$(wget -qO- https://api.github.com/repos/alis-is/ami/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | tr -d '[:space:]')
    fi
fi

# install eli
echo "Downloading eli setup script..."
if ! "$@" https://raw.githubusercontent.com/alis-is/eli/master/install.sh; then
    echo "failed to download eli, please retry ... "
    rm "$TMP_NAME"
    exit 1
fi

if ! sh "$TMP_NAME" $PRERELEASE_FLAG; then
    echo "failed to download eli, please retry ... "
    rm "$TMP_NAME"
    exit 1
fi
rm "$TMP_NAME"

if ami --version | grep "$LATEST"; then
    echo "latest ami already available"
    exit 0
fi

BIN="ami"
rm -f "/usr/local/bin/$BIN"
rm -f "/usr/bin/$BIN"
rm -f "/bin/$BIN"
rm -f "/usr/local/sbin/$BIN"
rm -f "/usr/sbin/$BIN"
rm -f "/sbin/$BIN"
# check destination folder
if [ -d "/usr/local/bin" ]; then
    DESTINATION="/usr/local/bin/$BIN"
elif [ -d "/usr/bin" ]; then
    DESTINATION="/usr/bin/$BIN"
elif [ -d "/bin" ]; then
    DESTINATION="/bin/$BIN"
elif [ -d "/usr/local/sbin" ]; then
    DESTINATION="/usr/local/sbin/$BIN"
elif [ -d "/usr/sbin" ]; then
    DESTINATION="/usr/sbin/$BIN"
elif [ -d "/sbin" ]; then
    DESTINATION="/sbin/$BIN"
else
    echo "no suitable destination folder found" 1>&2
    exit 1
fi

# install ami
echo "Downloading ami $LATEST..."
if "$@" "https://github.com/alis-is/ami/releases/download/$LATEST/ami.lua" &&
    cp "$TMP_NAME" "$DESTINATION" && rm "$TMP_NAME" && chmod +x "$DESTINATION"; then
    echo "ami $LATEST successfuly installed"
else
    rm "$TMP_NAME"
    echo "ami installation failed!" 1>&2
    exit 1
fi

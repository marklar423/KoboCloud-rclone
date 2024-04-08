#!/bin/sh
#Kobocloud getter

TEST=$1

#load config
. $(dirname $0)/config.sh

#check if Kobocloud contains the line "UNINSTALL"
if grep -q '^UNINSTALL$' $UserConfig; then
    echo "Uninstalling KoboCloud!"
    $KC_HOME/uninstall.sh
    exit 0
fi

RCLONE_OP=""
if grep -q "^REMOVE_DELETED$" $UserConfig; then
	echo "$Lib/filesList.log" > "$Lib/filesList.log"
    echo "Will delete files no longer present on remote"
    # Remove deleted, do a sync.
    RCLONE_OP="sync"
else
    # Don't remove deleted, do a copy.
    RCLONE_OP="copy"
fi


if [ "$TEST" = "" ]
then
    #check internet connection
    echo "`$Dt` waiting for internet connection"
    r=1;i=0
    while [ $r != 0 ]; do
    if [ $i -gt 60 ]; then
        ping -c 1 -w 3 aws.amazon.com >/dev/null 2>&1
        echo "`$Dt` error! no connection detected" 
        exit 1
    fi
    ping -c 1 -w 3 aws.amazon.com >/dev/null 2>&1
    r=$?
    if [ $r != 0 ]; then sleep 1; fi
    i=$(($i + 1))
    done
fi

# check for qbdb
if [ "$PLATFORM" = "Kobo" ]
then
  if [ -f "/usr/bin/qndb" ]
  then
      echo "NickelDBus found"
  else
      echo "NickelDBus not found: installing it!"
      wget "https://github.com/shermp/NickelDBus/releases/download/0.2.0/KoboRoot.tgz" -O - | tar xz -C /
  fi
  RCLONEVERSION=1.66.0
  RCLONESIZE=56885400
  if [[ -f "${RCLONE}"  &&  $(stat -c %s "${RCLONE}") = "${RCLONESIZE}" ]]
  then
      echo "rclone found"
  else
      echo "rclone not found: installing rclone version ${RCLONEVERSION} (size ${RCLONESIZE})!"
      mkdir -p "${RCLONEDIR}"
      rcloneTemp="${RCLONEDIR}/rclone.tmp.zip"
      rm -f "${rcloneTemp}"
      # get rclone distribution with wget, unzip it, but remove it if it failed
      wget "https://github.com/rclone/rclone/releases/download/v${RCLONEVERSION}/rclone-v${RCLONEVERSION}-linux-arm-v7.zip" -O "${rcloneTemp}" &&
      unzip -p "${rcloneTemp}" rclone-v${RCLONEVERSION}-linux-arm-v7/rclone > ${RCLONE} || rm ${RCLONE}
      rm -f "${rcloneTemp}"
  fi
fi

while read url || [ -n "$url" ]; do
  if echo "$url" | grep -q '^#'; then
    continue
  elif [ -n "$url" ]; then
    echo "Getting $url"    
    remote=$(echo "$url" | cut -d: -f1)
    dir="$Lib/$remote/"
    mkdir -p "$dir"
    RCLONE_COMMAND="${RCLONE} ${RCLONE_OP} --no-check-certificate --error-on-no-transfer -v --config ${RCloneConfig}"
    echo ${RCLONE_COMMAND} \"$url\" \"$dir\"
    ${RCLONE_COMMAND} "$url" "$dir"
  fi
done < $UserConfig

if [ "$TEST" = "" ]
then
    # Use NickelDBus for library refresh
    /usr/bin/qndb -t 3000 -s pfmDoneProcessing -m pfmRescanBooksFull
fi

rm "$Logs/index" >/dev/null 2>&1
echo "`$Dt` done"

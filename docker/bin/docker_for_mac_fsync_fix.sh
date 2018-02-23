#!/bin/bash

# Tune fsync perf for docker mac per
# https://github.com/docker/for-mac/issues/668
# From https://github.com/docker/for-mac/issues/668#issuecomment-284028148

# Docker has a [bug](https://github.com/docker/for-mac/issues/668) which slows down mysql instances    
#   - [Reason](https://github.com/docker/for-mac/issues/668#issuecomment-248011625)
#   - Fix
#     - Run `docker/bin/docker_for_mac_fsync_fix.sh`
#     - [script source](https://github.com/freshdesk/labs/blob/labs-arvind/docker/docker_for_mac_fsync_fix.sh)
#       - Script derived from [1](https://github.com/docker/for-mac/issues/668#issuecomment-284028148) and [2](https://github.com/docker/for-mac/issues/668#issuecomment-292948953)

set -e
cd ~/Library/Containers/com.docker.docker/Data/database
git reset --hard

#Incase the files are not present
echo -n "Creating the necessary files incase they are not present"
mkdir -p ./com.docker.driver.amd64-linux/disk
touch ./com.docker.driver.amd64-linux/disk/full-sync-on-flush
touch ./com.docker.driver.amd64-linux/disk/on-flush

echo -n "Current full-sync-on-flush setting: "
cat ./com.docker.driver.amd64-linux/disk/full-sync-on-flush
echo

echo -n "Current on-flush setting: "
cat ./com.docker.driver.amd64-linux/disk/on-flush
echo

echo -n false > ./com.docker.driver.amd64-linux/disk/full-sync-on-flush
echo -n none > ./com.docker.driver.amd64-linux/disk/on-flush

git add ./com.docker.driver.amd64-linux/disk/full-sync-on-flush
git add ./com.docker.driver.amd64-linux/disk/on-flush
git commit -s -m "disable flushing"

echo "Please restart docker"

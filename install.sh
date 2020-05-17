#!/bin/bash
# install Dependencies
# Ghosthub (b@b@y)

# ===== Check Sudo =======
if [ $(id -u) != "0" ]; then
    echo "You need to be root to run this software, try:\nsudo ./install"
echo "\n"
    exit 1
fi
# ========================


echo "Installing dependencies...." 
sleep 5
apt install apktool openjdk-11-jdk msfpc

echo "Thanks! Done!"
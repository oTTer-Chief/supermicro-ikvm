#!/bin/bash

### user config ###

# proxy server (ssh target)
PROXY=fles

# BMC config
USER=ADMIN
PW=ADMIN
R_WEB=80
R_SSL=443
R_VNC=5900
R_MEDIA=623

### end user config ###

set -e
#set -x

finish () {
    kill $SSH_PID 2>/dev/null
    rm $COOKIE
    rm $JNLP
}
trap finish EXIT

if [ $# -ne 1 ]; then
    echo "usagen: '$0 <hostname>'"
    exit
fi
NODE=$1
HOST=$NODE

echo "*** finding unused ports ***"
SUCCESS=0
INDEX=0
while [ $SUCCESS -ne 1 ]; do
    L_WEB=$((1080 + $INDEX))
    L_SSL=$((1443 + $INDEX))
    L_VNC=$((6900 + $INDEX))
    L_MEDIA=$((1623 + $INDEX))
    if [ `nmap --open -p $L_WEB,$L_SSL,$L_VNC,$L_MEDIA localhost | wc -l` -ne 3 ]; then
        INDEX=$(($INDEX + 1))
        echo "*** trying again ..."
    else
        SUCCESS=1
    fi
done

echo "*** forwarding ports ***"
ssh $PROXY -N -L $L_WEB:$HOST:$R_WEB -L $L_SSL:$HOST:$R_SSL -L $L_VNC:$HOST:$R_VNC -L $L_MEDIA:$HOST:$R_MEDIA &
SSH_PID=$!
sleep 2

echo "*** getting a session ID ***"
COOKIE=$(mktemp)
wget --save-cookies $COOKIE --keep-session-cookies --post-data name=$USER\&pwd=$PW --delete-after http://localhost:$L_WEB/cgi/login.cgi
SID=$(grep SID $COOKIE | awk '{print $7}')

echo "*** getting launch.jnlp ***"
JNLP=launch_$NODE.jnlp
wget -O $JNLP.tmp --load-cookies $COOKIE --post-data 'url_name=sess_&url_type=jwsk' http://localhost:$L_WEB/cgi/url_redirect.cgi

# fix ports in jnlp
sed -e s/localhost:$R_SSL/localhost:$L_SSL/g -e s/$R_VNC/$L_VNC/g -e s/$R_MEDIA/$L_MEDIA/g $JNLP.tmp > $JNLP
rm $JNLP.tmp

echo "*** launching KVM ***"
open $JNLP

wait

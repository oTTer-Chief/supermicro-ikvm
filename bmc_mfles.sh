#!/bin/bash
#set -e

NODE=pn01-bmc
HOST=$NODE

INDEX=01

R_WEB=80
R_SSL=443
R_VNC=5900
R_MEDIA=623

L_WEB=$((1080 + $INDEX))
L_SSL=$((1443 + $INDEX))
L_VNC=$((6900 + $INDEX))
L_MEDIA=$((1623 + $INDEX))

cleanup () {
    kill $SSH_PID
    rm $COOKIE
    rm $JNLP
}
trap cleanup SIGINT SIGTERM SIGHUP

echo "*** forward ports ***"
ssh fles -N -L $L_WEB:$HOST:$R_WEB -L $L_SSL:$HOST:$R_SSL -L $L_VNC:$HOST:$R_VNC -L $L_MEDIA:$HOST:$R_MEDIA &
SSH_PID=$!
sleep 2

echo "*** get a session ID ***"
COOKIE=$(mktemp)
wget --save-cookies $COOKIE --keep-session-cookies --post-data 'name=ADMIN&pwd=ADMIN' --delete-after http://localhost:$L_WEB/cgi/login.cgi
SID=$(grep SID $COOKIE | awk '{print $7}')

# create a proper jnlp
JNLP=launch_$NODE.jnlp
sed -e s/#SSL#/$L_SSL/g -e s/#VNC#/$L_VNC/g -e s/#MEDIA#/$L_MEDIA/g -e s/#SID#/$SID/g launch_mfles.template > $JNLP

echo "*** launch KVM ***"
open $JNLP

wait

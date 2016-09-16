#!/bin/bash
if [ -z "$1" ]; then
echo "Must pass in start, stop or status"
exit
fi
DIR=`dirname $0`
CURRENT_DIR=`cd $DIR;pwd`
pushd $CURRENT_DIR

case $1 in
start)
rm -rf database
mkdir database
rm mongodb.out
bin/mongod --dbpath database >> mongodb.out 2>&1 &
while [ `grep -c "db version v3.0.3" mongodb.out` -lt 1 ]
do
sleep 2
done
echo "mongo started at `date`"
;;
stop)

bin/mongod --dbpath database  --shutdown
;;
status)
ps -ef|grep mongod|grep -v grep
;;
esac

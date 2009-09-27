#!/bin/bash

if [ "$#" -lt 2 ]
then
  cat<<EOF
  Usage: $0 N <cmd>
    run <cmd> in background process;
    if process does not finish before N seconds, it is killed
EOF
  exit -1
fi

# parse input
TO=$1
shift
CMD=$*
echo "$0: command=<$CMD> timeout=$TO"

# run the real command in background
$CMD &
CMDPID=$!
echo "$0: command PID=$CMDPID"

# run a process that wait TO and try to kill CMD process if it exists
( 
  sleep $TO &&
  if [ -n "`ps -p ${CMDPID} | grep ${CMDPID}`" ] ;
  then
    echo "$0: Timeout! kill command."
    kill $CMDPID
  fi
) &
MONPID=$!
echo "$0: monitor PID=$MONPID"

# wait end of CMD process (normal end or killed by MON)
trap "kill $CMDPID $MONPID; exit -1" INT KILL
wait $CMDPID
R=$?
echo "$0: command exited: $R"

# we kill the MON process (if still running after CMD finished)
if [ -n "`ps -p ${MONPID} | grep ${MONPID}`" ]
then
  echo "$0: stopping monitor process"
  kill $MONPID
fi

# return result of CMD process
exit $R

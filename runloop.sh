ME=$0
ACT=$1
shift
APP=$1
shift
ARGS=$*

#TODO option to count failures and retry limited number of time
#TODO option to set interval to sleep before restart (0 is dangerous)
#TODO option for command to run to send alert (email, IM, URL, ...)
#TODO send end-of-alert after successful restart
#TODO http to enable to start/stop
#TODO http to provide basic interface (status + start/stop buttons)

CMD=$ARGS

#TODO add option for log/pid folder config
D_PID=./log

mkdir -p $D_PID

MON_LOG_FILE=$D_PID/$APP.mon.log
MON_PID_FILE=$D_PID/$APP.mon.pid
CMD_PID_FILE=$D_PID/$APP.cmd.pid

LOGH='date --rfc-3339=ns'

function _alert() {
  echo "ALERTTTTTTTT!!!!!"
}

function do_start() {
  (
  echo "`$LOGH`: monitor: start" >> $MON_LOG_FILE
  while true
  do
    eval "$CMD &"
    EVAL_RET=$?
    CMD_PID=$!
    if [ $EVAL_RET != 0 ]
    then
      sleep 1 # give time to parent process to write "START" message in log file
      echo "`$LOGH`: monitor: ERROR: command eval failed: $EVAL_RET" >> $MON_LOG_FILE
      echo "`$LOGH`: monitor: stop" >> $MON_LOG_FILE
      echo "STOP" >> $MON_PID_FILE
      break
    fi
    echo "`$LOGH`: monitor: command started: CMD_PID=$CMD_PID CMD=$CMD" >> $MON_LOG_FILE
    echo "$CMD_PID START" >> $CMD_PID_FILE
    wait $CMD_PID
    CMD_RET=$?
    echo "`$LOGH`: monitor: command stopped: PID=$CMD_PID RET=$CMD_RET" >> $MON_LOG_FILE
    echo "$CMD_PID STOP" >> $CMD_PID_FILE
    if [ $CMD_RET -eq 0 ]
    then
      echo "`$LOGH`: monitor: stop: normal end of command" >> $MON_LOG_FILE
      echo "STOP" >> $MON_PID_FILE
      break
    else
      #TODO can fail
      if [ "`tail -1 $MON_PID_FILE`" == "STOP REQUEST" ]
      then
        echo "`$LOGH`: monitor: loop: stop requested" >> $MON_LOG_FILE
        echo "STOP" >> $MON_PID_FILE
        break
      else
        echo "`$LOGH`: monitor: loop: restart command" >> $MON_LOG_FILE
        _alert
        sleep 1
      fi
    fi
  done
  ) &
  MON_PID=$!
  echo "$0: started monitor process MON_PID=$MON_PID MON_LOG_FILE=$MON_LOG_FILE"
  echo "$MON_PID START" >> $MON_PID_FILE
  sleep 1
  echo "$0: tail of monitor process log:"
  tail -4 $MON_LOG_FILE
  return 0
}

function do_stop() {
  echo "STOP REQUEST" >> $MON_PID_FILE
  #TODO can fail
  tail -1 $CMD_PID_FILE | cut -f1 -d' ' | xargs kill
  #TODO wait and kill -9 if needed ...
  return 0
}

function do_status() {
  #TODO can fail
  LOCAL_CMD_PID_FILE=$1
  if [ "$LOCAL_CMD_PID_FILE" == "" ]
  then
    LOCAL_CMD_PID_FILE=$CMD_PID_FILE
  fi
  PID=`tail -1 $LOCAL_CMD_PID_FILE | cut -f1 -d' '`
  CHK=`tail -1 $LOCAL_CMD_PID_FILE | cut -f2 -d' '`
  if [ "$CHK" == "START" ]
  then
    PS=`ps -p $PID | grep $PID`
  fi
  if [ "$PS" == "" ]
  then
    return -1
  else
    return 0
  fi
}

function do_http() {
  #http://paulbuchheit.blogspot.com/2007/04/webserver-in-bash.html
  RESP=/tmp/webresp
  [ -p $RESP ] || mkfifo $RESP
  while true ; do
    #TODO port in option
    ( cat $RESP ) | nc -l -p 9000 | (
      REQ_HEADER=`while read L && [ " " "<" "$L" ] ; do echo "$L" ; done`
      REQ=`echo "${REQ_HEADER}" | head -1`
      echo "[`date '+%Y-%m-%d %H:%M:%S'`] $REQ"
      REQPATH=`echo -n $REQ | cut -d' ' -f2`
      REQPATH0=`echo $REQPATH | cut -d'/' -f2` #appID
      REQPATH1=`echo $REQPATH | cut -d'/' -f3` #action
      REQPATH2=`echo $REQPATH | cut -d'/' -f4` #par1
      #TODO factor code
      LOCAL_MON_LOG_FILE=$D_PID/$REQPATH0.mon.log
      LOCAL_CMD_PID_FILE=$D_PID/$REQPATH0.cmd.pid
      if [ $REQPATH1 == "monlog" ]
      then
        if [ -e $LOCAL_MON_LOG_FILE ]
        then
          N=`echo "$REQPATH2" | grep "^[0-9]*$" | head -1`
          if [ "$N" == "" ] ; then N=4 ; fi
          if [ $N -gt 100 ] ; then N=4 ; fi
          ANS=`tail -$N $LOCAL_MON_LOG_FILE`
        else
          ANS="no monlog for app id ${REQPATH0}"
        fi
      elif [ $REQPATH1 == "status" ]
      then
        do_status $LOCAL_CMD_PID_FILE
        STATUS=$?
        if [ "$STATUS" == "0" ]
        then
          CMT="Running."
        else
          CMT="Not running."
        fi
        ANS="$STATUS $CMT"
      else
        ANS="unknown command"
      fi
      REP="${ANS}

${REQ_HEADER}"
      cat >$RESP <<EOF
HTTP/1.0 200 OK
Cache-Control: private
Content-Type: text/plain
Server: bash/2.0
Connection: Close
Content-Length: ${#REP}

$REP
EOF
    )
  done
}



#TODO display info on config

case "$ACT" in
  'start')
    do_status 
    if [ $? == 0 ]
    then
      echo "ERROR: $ACT: process already running"
    else
      do_start
    fi
    ;;
  'stop')
    do_status 
    if [ $? == 0 ]
    then
      do_stop
    else
      echo "ERROR: $ACT: process already running"
    fi
    ;;
  'status')
    do_status
    STATUS=$?
    if [ $STATUS == 0 ]
    then
      echo "process running"
    else
      echo "process not running"
    fi
    exit $STATUS
    ;;
  'http')
    do_http
    ;;
  *)
    echo <<EOF
Unknown command: $ACT
Usage:
  $0 start <appID> <command-line>
  $0 stop <appID>
  $0 status <appID>
  $0 http
  
  appID: uniq identifier of the running process (used in pid file name)
EOF
    ;;
esac

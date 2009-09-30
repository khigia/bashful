ME=$0
APP=$1
shift
ACT=$1
shift
ARGS=$*

#TODO option to set interval to sleep before restart (0 is dangerous)
#TODO option to count failures and retry limited number of time
#TODO option for command to run to send alert (email, IM, URL, ...)
#TODO send end-of-alert after successful restart

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
  sleep 0.5
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
  PID=`tail -1 $CMD_PID_FILE | cut -f1 -d' '`
  CHK=`tail -1 $CMD_PID_FILE | cut -f2 -d' '`
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
  *)
    echo "Unknown command: $ACT"
    echo "Usage: $0 <appID> start|stop|status <command-line>"
    echo "  appID: uniq identifier of the running process (used in pid file name)"
    ;;
esac

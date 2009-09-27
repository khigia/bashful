ME=$0
ACT=$1
shift
ARGS=$*

#TIMESTAMP on every log/file line
#TODO extract some cmd line options
APP="testapp"
CMD=$ARGS

D_PID=./log
D_LOG=./log

MON_PID_FILE=$D_PID/$APP.mon.pid
CMD_PID_FILE=$D_PID/$APP.cmd.pid


function _alert() {
  echo "ALERTTTTTTTT!!!!!"
}

#TODO display info on config

case "$ACT" in
  'start')
    (
    echo "monitor: start"
    while true
    do
      eval "$CMD &"
      CMD_PID=$!
      echo "monitor: command started: CMD_PID=$CMD_PID"
      echo "$CMD_PID START" >> $CMD_PID_FILE
      wait $CMD_PID
      CMD_RET=$?
      echo "monitor: command stopped: PID=$CMD_PID RET=$CMD_RET"
      echo "$CMD_PID STOP" >> $CMD_PID_FILE
      if [ $CMD_RET -eq 0 ]
      then
        echo "monitor: stop: normal end of command"
        break
      else
    #TODO can fail
        if [ "`tail -1 $MON_PID_FILE`" == "STOP REQUEST" ]
        then
          echo "monitor: loop: stop requested"
          echo "STOP" >> $MON_PID_FILE
          break
        else
          echo "monitor: loop: restart command"
          _alert
          sleep 1
        fi
      fi
    done
    ) &
    MON_PID=$!
    echo "$0: started monitor process MON_PID=$MON_PID"
    echo "$MON_PID START" >> $MON_PID_FILE
    ;;
  'stop')
    echo "STOP REQUEST" >> $MON_PID_FILE
    #TODO can fail
    tail -1 $CMD_PID_FILE | cut -f1 -d' ' | xargs kill
    ;;
  'status')
    ;;
  *)
    echo "Unknown command."
    echo "Usage: $0 [start|stop|status]"
    ;;
esac

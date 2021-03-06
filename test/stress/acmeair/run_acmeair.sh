#!/bin/bash
#shopt -s -o nounset

#  Optional variables:
#    SDK_DIR: base dir containing SDKs, eg: /home/user/nodejs/node-v0.10.26-linux-x64
#    JMETER_EXEC: driver program eg: /home/user/Jmeter/bin/jmeter
#    RESULTSDIR: results dir (default ./results)
#    DURATION: duration of the test run
#    INSTANCES: no of concurrent instances default (8)
#    PORT: driver machine port (default 4000) eg: 4000
#    DRIVERNO: the number of concurrent drivers (default 16) eg: 16

START=`date +%s`

function optional()
{
    if [ -z "${!1}" ]; then
        echo -n "${1} not set (ok)"
        if [ -n "${2}" ]; then
            echo -n ", default is: ${2}"
            export ${1}="${2}"
        fi
        echo ""
    fi
}

function archive_files()
{
    # archive files
    echo -e "\n##BEGIN $TEST_NAME Archiving $(date)\n"
    mv $LOGDIR_TEMP/$LOGDIR_PREFIX $RESULTSDIR
    echo -e "Perf logs stored in $RESULTSDIR/$LOGDIR_PREFIX"
    echo -e "\nCleaning up"
    rm -r $LOGDIR_TEMP
    echo -e "\n## END $TEST_NAME Archiving $(date)\n"
}

function kill_bkg_processes()   # kill processes started in background
{
    echo "Killing due to : $@"
    $MONGODB_COMMAND "stop"
    pkill mongod
    pkill node

    # If the host is Jenkins slave, prevent from killing it.
    JAVA_PID="`ps -ef|grep java|grep -v grep|grep -v slave|awk {'print $2'}`"
    kill -9 $JAVA_PID || true

    pids=$(ps -eo pid,pgid | awk -v pid=$$ '$2==pid && $1!=pid {print $1}')  # get list of all child/grandchild pids
    echo "Killing background processes"
    echo $pids
    kill -9 $pids || true  # avoid failing if there is nothing to kill
}

function clean_up()
{
    # Remove mongodb files.
    rm -rf ${MONGO_DIR}/database

    # Remove acmeair module files.
    rm -rf ${ACMEAIR_DIR}/node_modules

    rm -f ${SCRIPT_DIR}/jmeter.out
    mv jmeter.log $RESULTSDIR/$LOGDIR_PREFIX
}

function on_exit()
{
    echo "Caught kill"
    kill_bkg_processes "caught kill"
    kill -9 $PID_LIST $SPAREPID_LIST
    archive_files
    clean_up
    exit 1
}

function timestamp()
{
    date +"%Y%m%d-%H%M%S"
}

trap on_exit SIGINT SIGQUIT SIGTERM

# VARIABLE SECTION

# define variables
declare -rx SCRIPT=${0##*/}
TEST_NAME=acmeair
echo -e "\n## TEST: $TEST_NAME ##\n"
echo -e "## OPTIONS ##\n"

# Directory of main script file.
ROOT_DIR=`cd "$(dirname $0)/.."; pwd`
echo "ROOT_DIR: $ROOT_DIR"
SCRIPT_DIR=${ROOT_DIR}/acmeair
ACMEAIR_DRIVER_PATH=${SCRIPT_DIR}/jmeter

# Directories for script resources, e.g. mongo,acmeair
RESOURCE_DIR=$1
optional ACMEAIR_DIR ${RESOURCE_DIR}/acmeair-nodejs
optional MONGO_DIR ${RESOURCE_DIR}/mongo
optional JMETER_EXEC ${RESOURCE_DIR}/Jmeter/bin/jmeter

optional SDK_DIR
optional RESULTSDIR ${ROOT_DIR}/results
optional DURATION 3600
TIMEOUT=$(($DURATION + 600))
RESULTSLOG=$TEST_NAME.log
SUMLOG=score_summary.txt

# mandatory CPUAFFINITY
optional INSTANCES 8
optional NODE_FILE app.js
optional PORT 4000
optional DRIVERNO 25

NODE_SERVER=$(hostname -s)

echo -e "RESULTSDIR: $RESULTSDIR"
echo -e "RESULTSLOG: $RESULTSLOG"
echo -e "DURATION: $DURATION"
echo -e "INSTANCES: $INSTANCES"
echo -e "NODE_SERVER: $NODE_SERVER"
echo -e "PORT: $PORT"
echo -e "JMETER_EXEC: $JMETER_EXEC"
echo -e "DRIVERNO: $DRIVERNO\n"

JMETER_LOGFILE=${ACMEAIR_DRIVER_PATH}/jmeter.log
JMETER_COMMAND="$JMETER_EXEC -Jduration=$DURATION -Jdrivers=$DRIVERNO -Jhost=$NODE_SERVER -Jport=$PORT -DusePureIDs=true -n -t ${ACMEAIR_DRIVER_PATH}/AcmeAir.jmx -p ${ACMEAIR_DRIVER_PATH}/acmeair.properties -l $JMETER_LOGFILE"

# END VARIABLE SECTION

# Date stamp for result files generated by this run
CUR_DATE=$(timestamp)

PLATFORM=`/bin/uname | cut -f1 -d_`
echo -e "Platform identified as: ${PLATFORM}\n"

if [ -z "$SDK_DIR"]; then
  NODE=`which node`
else
  NODE=${SDK_DIR}/bin/node
fi

if [ -z "$NODE"  ]; then
    echo "ERROR: Could not find a 'node' executable. Please set the NODE environment variable or update the PATH."
    echo "node is not here: $NODE"
    exit 1
fi

echo -e "NODE: $NODE\n"
echo -e "NODE VERSION:"
$NODE --version

# build command
CMD="$NODE $NODE_FILE $INSTANCES $PORT"

export LOGDIR_TEMP=$RESULTSDIR/temp
mkdir -p $LOGDIR_TEMP
DONEFILE_TEMP=$LOGDIR_TEMP/donefile.tmp
echo -e "\nDONE file: $DONEFILE_TEMP"
echo -n > $DONEFILE_TEMP

# start time clock
( sleep $TIMEOUT; echo "TIMEOUT (${TIMEOUT}s)"; echo "fail" >> $DONEFILE_TEMP; ) &
TIMEOUT_PID=$!
SPAREPID_LIST="$SPAREPID_LIST $TIMEOUT_PID"

LOGDIR_PREFIX=$CUR_DATE
SUMFILE=$LOGDIR_TEMP/$LOGDIR_PREFIX/$SUMLOG
STDOUT_SERVER=$LOGDIR_TEMP/$LOGDIR_PREFIX/server.out
STDERR_SERVER=$LOGDIR_TEMP/$LOGDIR_PREFIX/server.err
STDOUT_CLIENT=$LOGDIR_TEMP/$LOGDIR_PREFIX/client.out
STDOUT_DB=$LOGDIR_TEMP/$LOGDIR_PREFIX/db.out
OUT_LIST="$OUT_LIST $LOGDIR_PREFIX/$SUMLOG $LOGDIR_PREFIX/server.out $LOGDIR_PREFIX/server.err $LOGDIR_PREFIX/client.out $LOGDIR_PREFIX/db.out"
echo -e "\n*** SUMMARY FILE  $SUMFILE ***\n"

echo -e "\n##START TEST INSTANCES $(date)\n"

echo
echo "*** BEGIN RUN ***"
LOGDIR_SHORT=$LOGDIR_PREFIX
LOGDIR_LONG=$LOGDIR_TEMP/$LOGDIR_SHORT
mkdir -p $LOGDIR_LONG
LOGFILE=$LOGDIR_LONG/$RESULTSLOG
rm -f $LOGFILE
OUT_LIST="$OUT_LIST $LOGDIR_SHORT/$RESULTSLOG"
echo "*** LOGFILE  $LOGFILE ***"

# Start MongoDB
MONGODB_COMMAND="${MONGO_DIR}/mongodb.sh"
echo -e "\n## STARTING MONGODB ##" 2>&1 | tee -a $LOGFILE
echo -e " $MONGODB_COMMAND start" 2>&1 | tee -a $LOGFILE
$MONGODB_COMMAND start
sleep 5     # give it a chance to start up

# Start the server(s)
echo -e "\n## SERVER COMMAND ##" 2>&1 | tee -a $LOGFILE
echo -e "$CMD" 2>&1 | tee -a $LOGFILE
echo -e "## BEGIN TEST ##\n" 2>&1 | tee -a $LOGFILE

# Install node modules for acmeair.
NPM=`dirname ${NODE}`
${NPM}/npm install --prefix ${ACMEAIR_DIR} > /dev/null 2>&1

(
    pushd $ACMEAIR_DIR
    # $CMD > $STDOUT_SERVER 2> $STDERR_SERVER
    $CMD > /dev/null 2> $STDERR_SERVER
    echo -e "\n## Server no longer running ##"
    echo "fail" >> $DONEFILE_TEMP
    popd
) &
sleep 10 # give server some time to start up

echo "${SCRIPT_DIR}/loaddb.sh ${NODE_SERVER} ${PORT}"
${SCRIPT_DIR}/loaddb.sh ${NODE_SERVER} ${PORT}

if [ "$?" != "0" ]; then
  echo "Database could not be loaded."
  kill_bkg_processes "Could not load DB"
  archive_files
  clean_up
  exit 1
fi

sleep 5

echo -e "\n## DRIVER COMMAND ##" 2>&1 | tee -a $LOGFILE
echo -e "$JMETER_COMMAND" | tee -a $LOGFILE
(
    if (exec $JMETER_COMMAND 2>&1 | tee -a $LOGFILE jmeter.out) ; then
        echo "Drivers have finished running" 2>&1 | tee -a $LOGFILE
        echo "done" >> $DONEFILE_TEMP
    else
        echo "ERROR: driver failed or killed" 2>&1 | tee -a $LOGFILE
        echo "fail" >> $DONEFILE_TEMP
    fi
) &
sleep 2

while ! grep done $DONEFILE_TEMP &>/dev/null ; do
    sleep 3
    # Abort the run if an instance fails or if we time out
    if grep fail $DONEFILE_TEMP &>/dev/null ; then
        on_exit
    fi
done

kill_bkg_processes "Should be finished"

echo -e "\n## END RUN ##"

echo "cat mongodb.out" > $STDOUT_DB
cat ${MONGO_DIR}/mongodb.out > $STDOUT_DB
echo "cat jmeter.out" > $STDOUT_CLIENT
cat jmeter.out > $STDOUT_CLIENT

# print output
echo -e "\n##BEGIN $TEST_NAME OUTPUT $(date)\n" 2>&1 | tee -a $SUMFILE
echo cat $JMETER_LOGFILE
METRIC_THROUGHPUT=$(cat $JMETER_LOGFILE | awk -f ${SCRIPT_DIR}/acmeair_score.awk)
METRIC_LATENCY=$(cat $JMETER_LOGFILE | sed 's/ //g' | sed 's/,/ /g' | awk 'BEGIN { COUNT=0; SUM=0 } { SUM=SUM+$10; COUNT=COUNT+1 } END { print SUM/COUNT }')

if [ -z "$METRIC_THROUGHPUT" -o "$METRIC_THROUGHPUT" == "0" -o -z "$METRIC_LATENCY" -o "$METRIC_LATENCY" == "0" ]; then
  echo "There is something wrong with the test output metrics."
  kill_bkg_processes "Wrong test output"
  archive_files
  clean_up
  exit 1
fi
echo metric throughput $METRIC_THROUGHPUT 2>&1 | tee -a $SUMFILE
echo metric latency $METRIC_LATENCY 2>&1 | tee -a $SUMFILE

rm -f $JMETER_LOGFILE
echo -e "\n## TEST COMPLETE ##\n" 2>&1 | tee -a $SUMFILE
echo -e "\n## END $TEST_NAME OUTPUT $(date)\n\n" 2>&1 | tee -a $SUMFILE

END=`date +%s`
ELAPSED=$(($END - $START))
echo "Elapsed time : $ELAPSED"

archive_files
clean_up

# Acmeair long running test

## Purpose
Acmeair long running test was designed to stress Node.js runtime by running an application with an increased load for a long period of time (from couple of hours to weeks) and seeing whether/when Node.js would crash.

##Default directory structure
•	mongo – MongoDB database system
•	acmeair-nodejs – acmeair application files
•	acmeair – runner scripts, database loading script and Jmeter settings
•	Jmeter – application to drive acmeair
•	results – directory where results are stored after the run

##Set up
Copy app.js and/or app_nocluster.js into acmeair-nodejs directory (if default was used)
Copy mongodb.sh into mongo directory (if default was used)

##Running the tests
Before starting the test, some environment variables can be set first (NB: all the environment variables are optional, read below for more information):
SDK_DIR – name of Node.js directory, eg: /home/user/node-4.5.0, if left empty Node.js SDK specified on the path would be used
ACMEAIR_DIR – directory of Acmeair application
MONGO_DIR – directory of MongoDB files
ACMEAIR_DRIVER_PATH – directory path to the Jmeter settings
JMETER_EXEC – Jmeter executable
DURATION – duration of the test run in seconds (default: 1h)
INSTANCES – number of concurrent Acmeair instances (default: 8)
PORT – driver machine port (default: 4000)
DRIVERNO – number of concurrent drivers, used by driver program (default: 16)
NODE_FILE – node application to run - app.js or app_nocluster.js (default: app.js)
RESULTSDIR – location of the result files

Then in the acmeair directory run a command: `./run-acmeair.sh <RESOURCE_DIR>`
RESOURCE_DIR is used when setting ACMEAIR_DIR, MONGO_DIR, ACMEAIR_DRIVER_PATH and DRIVERCMD (e.g. if RESOURCE_DIR=/home/user/acmeair, then MONGO_DIR=/home/user/acmeair/mongo). If it is left out, all of the aforementioned environment variables have to be set before running the script.

The script will first start a local MongoDB instance and load the data into it. Then it will kick off acmeair application in the background and start sending API calls to it using Jmeter. The test should finish in the amount of time specified in DURATION plus the time for starting and loading the database (~ 2-3mins).
NB: The application is set to timeout if it exceeds the time set in DURATION by 10 minutes.
There are two Node.js applications included in the test suite that could be used (specified in NODE_FILE):
•	app.js – modified version of original Acmeair application, includes support for multiple concurrent instances of the application (specify the number by setting INSTANCES)
•	app_nocluster.js – single instance of Acmeair application
Acmeair error output is stored in server.err file in results directory, and standart output is suppressed by default in order to save space, if you want enable it change:
`$CMD > /dev/null 2> $STDERR_SERVER` to `$CMD > $STDOUT_SERVER 2> $STDERR_SERVER` inside run_acmeair.sh

##System requirements
At least 3GB of free space.

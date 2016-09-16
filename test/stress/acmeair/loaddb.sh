#!/bin/bash
host=$1
port=$2

wget -O- http://${host}:${port}/rest/api/loaddb

#!/bin/bash
set -x
. /home/oracle/dba/scripts/define mmso

echo "@/home/app/orahome/product/11.2.0.4/delete.sql" | sqlplus canal_plus/wsx3edc


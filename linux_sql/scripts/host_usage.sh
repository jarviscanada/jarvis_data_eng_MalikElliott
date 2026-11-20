#!/bin/bash

psql_host=$1
port=$2
db_name=$3
psql_user=$4
psql_password=$5

if [ "$#" -ne 5 ]; then
	echo "Illegal number of parameters"
	exit 1
fi

vmstat_mb=$(vmstat --unit M)
hostname=$(hostname -f)

memory_free=$(vmstat --unit M | tail -1 | awk -v col="4" '{print $col}')
cpu_idle=$(vmstat | tail -1 | awk '{print $15}')
cpu_kernel=$(vmstat | tail -1 | awk '{print $13}')
disk_io=$(vmstat --unit M -d | tail -1 | awk -v col="10" '{print $col}')
disk_available=$(vmstat --unit M -d | tail -1 | awk -v col="4" '{print $col}')

timestamp=$(date +"%Y-%m-%d %H:%M:%S")

host_id="(SELECT id FROM host_info WHERE hostname='$hostname')";

insert_stmt="INSERT INTO host_usage("timestamp", memory_free, cpu_idle, cpu_kernel, disk_io, disk_available) VALUES('$timestamp','$memory_free','$cpu_idle','$cpu_kernel','$disk_io','$disk_available' )"


export PGPASSWORD=$psql_password

psql -h $psql_host -p $port -d $db_name -U $psql_user -c "$insert_stmt"
exit $?

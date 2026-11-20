
# Introduction
This project provides a database with Docker using the Linux Command Line (CLI); it sends the remote desktop's hardware information and usage to a database created with the CLI. 
The end users of this project are the LCA team; they run the commands to grab information and set everything up. I am the owner of the project because I created the files/scripts that ran everything.
However, the information I am grabbing isn't mine and belongs to Jarvis's Remote Desktop. 
Some of the technologies I used were: Bash (to run the scripts), Docker (so that the commands/tools can be run on any device, and Git (so I can save file changes and publish different versions).

# Quickstart
- psql_docker.sh
```bash
./scripts/psql_docker.sh start
```

- host_info.sh
```bash
./scripts/host_info.sh "localhost" 5432 "host_agent" "postgres" "password"
```

- host_usage.sh
```bash
bash scripts/host_usage.sh localhost 5432 host_agent postgres password
```

- crontab
```bash
bash /home/rocky/dev/jarvis_data_eng_MalikElliott/linux_sql/scripts/host_usage.sh localhost 5432 host_agent postgres password > /tmp/host_usage.log
```

- ddl.sql
```bash
psql  -h localhost -U postgres -d host_agent -f ./scripts/ddl.sql
```

# Implementation 
The project was implemented using scripts & Databases

## Architecture 
(./assets/psql_diagram.png)

## Scripts
ddl.sql: This file connects to the host agent DB and creates the tables if they don't exist
```sh
\c host_agent;

CREATE TABLE IF NOT EXISTS host_info
  (
     id               SERIAL NOT NULL,
     hostname         VARCHAR NOT NULL,
     cpu_number       INT2 NOT NULL,
     cpu_architecture VARCHAR NOT NULL,
     cpu_model        VARCHAR NOT NULL,
     cpu_mhz          FLOAT8 NOT NULL,
     l2_cache         INT4 NOT NULL,
     "timestamp"      TIMESTAMP NULL,
     total_mem        INT4 NULL,
     CONSTRAINT host_info_pk PRIMARY KEY (id),
     CONSTRAINT host_info_un UNIQUE (hostname)
  );


CREATE TABLE IF NOT EXISTS host_usage
  (
     "timestamp"    TIMESTAMP NOT NULL,
     host_id        SERIAL NOT NULL,
     memory_free    INT4 NOT NULL,
     cpu_idle       INT2 NOT NULL,
     cpu_kernel     INT2 NOT NULL,
     disk_io        INT4 NOT NULL,
     disk_available INT4 NOT NULL,
     CONSTRAINT host_usage_host_info_fk FOREIGN KEY (host_id) REFERENCES
     host_info(id)
  );
```

psql_docker.sh: runs a new Docker container instance if it is not already created
```sh
#!/bin/bash

cmd=$1
db_username=$2
db_password=$3

# Start docker
sudo systemctl status docker || systemctl #todo

# Check container status
docker container inspect jrvs-psql
container_status=$?

# User switch case to handle create|stop|start opetions
case $cmd in 
  create)
  
  # Check if the container is already created
 	if [ $container_status -eq 0 ]; then
		echo 'Container already exists'
		exit 1	
	fi

  # Check # of CLI arguments
  	if [ $# -ne 3 ]; then
    		echo 'Create requires username and password'
    		exit 1
 	 fi
  
  # Create container
  	docker pull postgres
  	export PGPASSWORD='password'
	docker volume create pgdata
  # Start the container
	docker run --name jrvs-psql -e POSTGRES_PASSWORD=$PGPASSWORD  -d -v pgdata:/var/lib/postgresql/data -p 5432:5432 postgres:9.6-alpine
	exit $?
	;;

  	start|stop) 
  # Check instance status; exit 1 if container has not been created
  	if [ $container_status -eq 1 ]; then
 	 # Start or stop the container
	 	exit 1
	fi


	docker container stop jrvs-psql
        docker container start jrvs-psql
	docker container $cmd jrvs-psql
	exit $?
	
	;;	
  
  	*)
	echo 'Illegal command'
	echo 'Commands: start|stop|create'
	exit 1
	;;
esac 
```

host_info.sh: Takes hardware information, puts it in variables, and inserts it into the host_info table
```sh
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

hostname=$(hostname -f)
cpu_number=$(lscpu | egrep "^CPU\(s\):" | awk '{print $2}' | xargs)
cpu_architecture=$(lscpu | egrep "Architecture" | awk '{print $2}' | xargs)
cpu_model=$(lscpu | egrep "Model name" | awk '{for (i=3; i<=7; i++) printf "%s ", $i; print ""}' | xargs)
cpu_mhz=$(lscpu | egrep "Model name" | awk '{print $7 *1000}'| tr -d "GHz" | xargs)
l2_cache=$(lscpu | egrep "L2 cache"  | awk '{print $3}' | xargs)
total_mem=$(vmstat --unit M | tail -1 | awk '{print $4}')
timestamp=$(date +"%Y-%m-%d %H:%M:%S")

insert_stmt="INSERT INTO host_info(hostname, cpu_number, cpu_architecture, cpu_model, cpu_mhz, l2_cache, total_mem, timestamp) VALUES('$hostname', '$cpu_number', '$cpu_architecture', '$cpu_model', '$cpu_mhz', '$l2_cache', '$total_mem', '$timestamp')";

export PGPASSWORD=$psql_password
psql -h $psql_host -p $port -d $db_name -U $psql_user -c "$insert_stmt"
exit $?
```

host_usage: Takes hardware/cpu usage, puts it in variables, and inserts it into the host_info table
```sh
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
```

## Database Modeling: 
'host_usage'
|      timestamp      | host_id | memory_free | cpu_idle | cpu_kernel | disk_io | disk_available |
|---------------------|---------|-------------|----------|------------|---------|----------------|

'host_info'
| id |                                     hostname                                     | cpu_number | cpu_architecture |           cpu_model            | cpu_mhz | l2_cache |      timestamp      | total_mem |
|----|----------------------------------------------------------------------------------|------------|------------------|--------------------------------|---------|----------|---------------------|-----------|

# Testing 
When testing, I first ran the Docker instance; after that was successful, I ran the DDL file to create the tables in case they hadn't been created.
After that, I ran the bash scripts to populate information into the tables. Finally, I connected to the psql instance to check if the tables were populated with the values.

# Deployment
After the code ran successfully, I used the crontab feature to handle updates to the host usage every minute, so that it will add a new entry to the host_usage table every minute.
Docker is used to deploy my application so that it can run on any device.
GitHub is where all of the versions and changes are saved.

# Improvements
A few improvements I would like to make are:
- Have all the scripts run automatically in order.
- Have it handle updates to the hardware, just in case my project stops being compatible with the current hardware.
- Create a script that can grab certain information, such as average CPU usage, etc and save those outputs

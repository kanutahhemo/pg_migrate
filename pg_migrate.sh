#!/bin/bash

####################################
###---check all env variables:---###
####################################

function env_message {
	echo -e "$1 postgres node $2 is: $3"
}

if [ -z ${PG_PROVIDER_VER+x} ] ; then
	
	read -p "Please provide postgres version of provider node [default is 9.5]: " pg_provider_ver_str
	if [ -z $pg_provider_ver_str ] ; then
			pg_provider_ver_str=9.5
	fi
	export PG_PROVIDER_VER=$pg_provider_ver_str
fi
message=$(env_message provider version $PG_PROVIDER_VER)
echo -e "\n$message\n"

if [ -z ${PG_SUBSCRIBER_VER+x} ] ; then
	
	read -p "Please provide postgres version of subscriber node [default is 11]: " pg_subscriber_ver_str
	if [ -z $pg_subscriber_ver_str ] ; then
			pg_subscriber_ver_str=11
	fi
	export PG_SUBSCRIBER_VER=$pg_subscriber_ver_str


fi

message=$(env_message subscriber version $PG_SUBSCRIBER_VER)
echo -e "\n$message\n"

if [ -z ${PG_PROVIDER_PORT+x} ] ; then
	
	read -p "Please provide postgres port of provider node [default is 5432]: " pg_provider_port_str
	if [ -z $pg_provider_port_str ] ; then
			pg_provider_port_str=5432
	fi
	export PG_PROVIDER_PORT=$pg_provider_port_str
fi

message=$(env_message provider port $PG_PROVIDER_PORT)
echo -e "\n$message\n"


if [ -z ${PG_SUBSCRIBER_PORT+x} ] ; then
	
	read -p "Please provide postgres port of subscriber node [default is 5433]: " pg_subscriber_port_str
	if [ -z $pg_subscriber_port_str ] ; then
			pg_subscriber_port_str=5433
	fi
	export PG_SUBSCRIBER_PORT=$pg_subscriber_port_str
fi

message=$(env_message subscriber port $PG_SUBSCRIBER_PORT)
echo -e "\n$message\n"

if [ -z ${PG_PROVIDER_BIN_PATH+x} ] ; then
	
	read -p "Please provide postgres bin path of provider node [default is /usr/lib/postgresql/$PG_PROVIDER_VER/bin]: " pg_provider_bin_path_str
	if [ -z $pg_provider_bin_path_str ] ; then
			pg_provider_bin_path_str="/usr/lib/postgresql/$PG_PROVIDER_VER/bin"
	fi
	export PG_PROVIDER_BIN_PATH=$pg_provider_bin_path_str
fi

message=$(env_message provider bin\ path $PG_PROVIDER_BIN_PATH)
echo -e "\n$message\n"

if [ -z ${PG_SUBSCRIBER_BIN_PATH+x} ] ; then
	
	read -p "Please provide postgres bin path of provider node [default is /usr/lib/postgresql/$PG_SUBSCRIBER_VER/bin]: " pg_subscriber_bin_path_str
	if [ -z $pg_subscriber_bin_path_str ] ; then
			pg_subscriber_bin_path_str="/usr/lib/postgresql/$PG_PROVIDER_VER/bin"
	fi
	export PG_SUBSCRIBER_BIN_PATH=$pg_subscriber_bin_path_str
fi

message=$(env_message provider bin\ path $PG_SUBSCRIBER_BIN_PATH)
echo -e "\n$message\n"


#dump roles
#dump_roles=$(sudo -u postgres pg_dumpall --schema-only > /tmp/dumpall.sql)
#restore_roles=$(sudo -u postgres psql -p 5433 -f /tmp/dumpall.sql)


#check configs and access
function check_config {

	params=""
	db_num=$1
	let max_worker_processes=3*$db_num

	if [ $2 -eq 0 ]; then
		port=$PG_PROVIDER_PORT
		bin_path=$PG_PROVIDER_BIN_PATH
	else
		port=$PG_SUBSCRIBER_PORT
		bin_path=$PG_SUBSCRIBER_BIN_PATH
	fi

	wal_level=$(sudo -u postgres $bin_path/psql -At -p $port -c "show wal_level")
	if [ $wal_level != "logical" ] ; then

		params+="\nwal_level=logical"
	fi
	if [ $2 -eq 0 ]; then 
		replication_slots=$(sudo -u postgres $bin_path/psql -At -p $port  -c "show max_replication_slots")
		if [ $replication_slots -lt $db_num ]; then

			params+="\nmax_replication_slots=$db_num"
		fi

		

		wal_senders=$(sudo -u postgres $bin_path/psql -At -p $port  -c "show max_wal_senders")
		if [ $wal_senders -lt $db_num ]; then

			params+="\nmax_wal_senders=$db_num"
		fi
	else
		worker_processes=$(sudo -u postgres $bin_path/psql -At -p $port  -c "show max_worker_processes")
		if [ $worker_processes -lt $max_worker_processes ]; then

			params+="\nmax_worker_processes=$max_worker_processes"
		fi	
	fi

	logical_preload_libruary=$(sudo -u postgres $bin_path/psql -At -p $port -c "show shared_preload_libraries")
	if [[ ${logical_preload_libruary} != *"pglogical"* ]]; then

		params+="\nshared_preload_libraries='pglogical' #dont forget to include other libraries if needed!!!"
	fi	


	echo $params

}

function check_pg_hba {
	pass
}


function create_provider_node {
	db=$1
	echo "create extension on provider node for $db\n"
	create_extension=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/psql -p $PG_PROVIDER_PORT -At -d $db -c "create extension pglogical")
	echo "create pglogical node on provider node for $db\n"
	create_node=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/psql -p $PG_PROVIDER_PORT -At -d $db -c "select * from pglogical.create_node(node_name:='$db', dsn:='host=127.0.0.1 port=$PG_PROVIDER_PORT dbname=$db')")
	echo "create replication set for tables and sequences on $db\n"
	create_replication_set_table=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/psql -p $PG_PROVIDER_PORT -At -d $db -c "select * from pglogical.replication_set_add_all_tables('default', ARRAY['public'])")
	create_replication_set_sequences=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/psql -p $PG_PROVIDER_PORT -At -d $db -c "select * from pglogical.replication_set_add_all_sequences('default', ARRAY['public'])")
}

function create_subscriber_node {
	db=$1
	pass=$2
	echo "create extension on subscriber node for $db\n"
	create_extension=$(sudo -u postgres $PG_SUBSCRIBER_BIN_PATH/psql -p $PG_SUBSCRIBER_PORT -At -d $db -c "create extension pglogical")
	echo "create pglogical node on subscriber node for $db\n"
	create_node=$(sudo -u postgres $PG_SUBSCRIBER_BIN_PATH/psql -p $PG_SUBSCRIBER_PORT -At -d $db -c "select * from pglogical.create_node(node_name:='sub_$db', dsn:='host=127.0.0.1 port=$PG_SUBSCRIBER_PORT dbname=$db user=su password=$pass')")
	echo "create pglogical subcription on subscriber node for $db\n"
	create_subscription=$(sudo -u postgres $PG_SUBSCRIBER_BIN_PATH/psql -p $PG_SUBSCRIBER_PORT -At -d $db -c "select * from pglogical.create_subscription(subscription_name:='subs_$db', provider_dsn:='host=127.0.0.1 port=$PG_PROVIDER_PORT dbname=$db user=su password=$pass')")
}

function check_replication {
	pass
}

function seq_sync {
	sync_comm=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/psql -p $PG_PROVIDER_PORT -At -d $db -c "select pglogical.synchronize_sequence( seqoid ) from pglogical.sequence_state")
}

databases=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/psql -p $PG_PROVIDER_PORT -At -c "select datname from pg_database" |grep -vE 'template' | tr "\ " "\n${databases[*]}")
db_num=0
for base in $databases; do
	db_num=$((db_num+1))
done
config_test=0

#checking provider configuration
provider_config_test=$(check_config $db_num 0)

if [ -z ${provider_config_test} ]; then
	echo "Provider node config is ok"
else
	echo -e "\n!!!Provider configuration is not ready!!!.\nPlease set this parameters at postgres configuration files: \n\n\n##########################\n##########################"$provider_config_test"\n\n--------------------------------------------------------" 
	config_test=1
fi

#checking subscriber configuration
subscriber_config_test=$(check_config $db_num 1)

if [ -z "${subscriber_config_test}" ]; then
	echo "Subscriber node config is ok"
else
	echo -e "\n!!!Subscriber configuration is not ready!!!.\nPlease set this parameters at postgres configuration files: \n\n##########################\n##########################"$subscriber_config_test"\n\n--------------------------------------------------------"
	config_test=1
fi

if [ $config_test -eq 1 ]; then
	echo "Fix configuration, restart PG and start once again"
	exit

fi	

##starting to replicate
supassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')

#create superuser to relicte initialisation
provider_su=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/psql -p $PG_PROVIDER_PORT -At -c "CREATE role su with login superuser replication encrypted password '$supassword'")

#dump_roles

echo "DUMP ROLES"

dump_roles=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/pg_dumpall -p $PG_PROVIDER_PORT --roles-only > /tmp/roles.sql)
restore_roles=$(sudo -u postgres $PG_SUBSCRIBER_BIN_PATH/psql -p $PG_SUBSCRIBER_PORT -f /tmp/roles.sql)



#create schema on subscriber
for db in $databases; do
	provider_schema_dump=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/pg_dump -p $PG_PROVIDER_PORT -d $db --schema-only > /tmp/$db.sql)
	subscriber_db_create=$(sudo -u postgres $PG_SUBSCRIBER_BIN_PATH/psql -p $PG_SUBSCRIBER_PORT -c "create database $db")
	subscriber_schema_create=$(sudo -u postgres $PG_SUBSCRIBER_BIN_PATH/psql -p $PG_SUBSCRIBER_PORT -d $db -f /tmp/$db.sql)
done

for db in $databases; do
	comm=$(create_provider_node $db)
	echo -e $comm
done

for db in $databases; do
	comm=$(create_subscriber_node $db $supassword)
	echo -e $comm
done

echo "sleep a while"
sleep 30

echo "resync all sequences"
for db in $databases; do
	comm=$(seq_sync $db)
	echo -e $comm
done

echo "Finish"

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
	if [ $2 -eq 1 ]; then 
		replication_slots=$(sudo -u postgres $bin_path/psql -At -p $port  -c "show max_replication_slots")
		if [ $replication_slots -lt $db_num ]; then

			params+="\nmax_replication_slots=$db_num"
		fi

		wal_senders=$(sudo -u postgres $bin_path/psql -At -p $port  -c "show max_wal_senders")
		if [ $wal_senders -lt $db_num ]; then

			params+="\nmax_wal_senders=$db_num"
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

#creating role for relpication
function create_superrole {
	pass
}
#sudo -u postgres psql -p 5433 -c "CREATE role su with superuser replication encrypted password 'asdf'"
#sudo -u postgres psql -p 5432 -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo "drop extension pglogical for $db"; sudo -u postgres psql -p 5432 -d $db -c "drop extension pglogical"; done
#sudo -u postgres psql -5432 -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo "drop schema pglogical for $db"; sudo -u postgres psql -p 5432 -d $db -c "create schema pglogical"; done
#sudo -u postgres psql -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo "create extension pglogical for $db"; sudo -u postgres psql -d $db -p 5432 -c "create extension pglogical"; done
#sudo -u postgres psql -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo "create extension pglogical for $db"; sudo -u postgres psql -d $db -p 5433 -c "create extension pglogical"; done
#echo "create providers_node"
#read -p "Press enter to continue"
#sudo -u postgres psql -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo $db; sudo -u postgres psql -p 5432 -d $db -c "select * from pglogical.create_node(node_name:='"$db"_provider', dsn:='host=127.0.0.1 port=5432 dbname=$db ')"; done
#echo "create replication table sets"
#read -p "Press enter to continue"
#sudo -u postgres psql -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo $db; sudo -u postgres psql -p 5432  -d $db -c " select * from pglogical.replication_set_add_all_tables('default', ARRAY['public']);"; done
#echo "create replication sequences set"
#read -p "Press enter to continue"
#sudo -u postgres psql -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo $db; sudo -u postgres psql -p 5432 -d $db -c " select * from pglogical.replication_set_add_all_sequences('default', ARRAY['public'], true);"; done
#echo "create subscriber node"
#read -p "Press enter to continue"
#sudo -u postgres psql -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo $db; sudo -u postgres psql -p 5433 -d $db -c "select * from pglogical.create_node(node_name:='"$db"_subscriber', dsn:='host=127.0.0.1 port=5433 dbname=$db user=su password=asdf')"; done
#echo "create subscription"
#read -p "Press enter to continue"
#sudo -u postgres psql -At -c "select datname from pg_database" |grep -vE 'template' |while read db ; do echo $db; sudo -u postgres psql -p 5433 -d $db -c "select * from pglogical.create_subscription(subscription_name:='"$db"_subscription', provider_dsn:='host=127.0.0.1 port=5432 dbname=$db user=su password=asdf')"; done
#echo "Wait a while..."
#status=$(replication_status $databases)
#echo $status
databases=$(sudo -u postgres $PG_PROVIDER_BIN_PATH/psql -At -c "select datname from pg_database" |grep -vE 'template' | tr "\ " "\n${databases[*]}")
db_num=0
for base in $databases; do
	db_num=$((db_num+1))
done

#checking provider configuration
provider_config_test=$(check_config $db_num 0)

if [ -z ${provider_config_test} ]; then
	echo "Provider node config is ok"
else
	echo -e "please set this parameters at postgres configuration files: \n"$provider_config_test
	exit
fi

#checking subscriber configuration
subscriber_config_test=$(check_config $db_num 1)

if [ -z ${subscriber_config_test} ]; then
	echo "Subscriber node config is ok"
else
	echo -e "please set this parameters at postgres configuration files: \n"$subscriber_config_test
	exit
fi

echo "Finish"

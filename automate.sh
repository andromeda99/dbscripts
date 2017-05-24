#!/bin/bash
usage() {
  echo "error:- please mention HOST & DB name while running the script"
  exit
}
#==== Checking if both parameters exist =====
if [ -z "$1" ] || [ -z "$2" ]; then
  usage
fi

echo "automate_link.sh consists all leading files & even if it terminates at cutover step then it shall continue from here."

./automate_link.sh $1 $2

HOST="$1"
DATABASE="$2"
DB=`echo $DATABASE | cut -d '_' -f 1`
x=`echo $?`
echo "The Ninth level ended in previous script & the exit status is $x."

list-dbs () {
        psql -U postgres -c 'SELECT datname FROM pg_database;'
}
gormley_scripts () {
	sudo environment-replicate/db/socialsense/after-production-replicate.sh postgres 5432 	
	sudo environment-replicate/db/socialsense/preserve_socialsense_env_data.sh postgres 5432
}
ss_storm_routing_rule () {
	sudo -u postgres psql -U postgres -d socialsense -f ss_storm_routing_rule.sql
}
ss_truncate_storm_topology () {
	psql -U postgres -d socialsense -c 'TRUNCATE storm_topology CASCADE;'
}
ss_dump_storm_topology () {
	cd /data/0/tmp
	sudo -u postgres mv /data/0/tmp/storm_topology.pg /data/0/tmp/storm_topology.pg.old
	sudo -u postgres /usr/pgsql-9.2/bin/pg_dump -Fc --data-only --table=storm_topology -f /data/0/tmp/storm_topology.pg socialsense_previous #dump
}
ss_load_storm_topology () {
	cd /data/0/tmp
	sudo -u postgres /usr/pgsql-9.2/bin/pg_restore --data-only --format=custom storm_topology.pg |psql -U postgres -d socialsense #load
}
unlock-database () {
	DATABASE="$1"
	psql -U postgres -c "ALTER DATABASE $DATABASE CONNECTION LIMIT -1;" 
}
spot-check () {
	DATABASE="$1"

# show size
	sudo -u postgres psql "$DATABASE" -c "SELECT nspname || '.' || relname AS "relation", \
        pg_size_pretty(pg_total_relation_size(C.oid)) AS "total_size" \
        FROM pg_class C \
        LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) \
        WHERE nspname NOT IN ('pg_catalog', 'information_schema') \
        AND C.relkind <> 'i' \
        AND nspname !~ '^pg_toast' \
        ORDER BY pg_total_relation_size(C.oid) DESC \
        LIMIT 10;"

	if [[ "$DATABASE" = socialsense ]] || [[ "$DATABASE" = socialsense_previous ]] ; then
	# show ownership of a table
	sudo -u postgres psql "$DATABASE" -c "\dt admin_user_role_groups"
	fi
}

#====(Main) 10th level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Executing gormley_scripts.sh - \"$DB"\"
         gormley_scripts
         x=`echo $?`
else
        echo "something does not look in automate_link.sh. Please try again...!!!"
        exit
fi
echo "The Tenth level ends here & the exit status is $x"
#====  11th  level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Executing storm_routing_rule"
	 ss_storm_routing_rule  
         x=`echo $?`
else
        echo "something does not look @ 10th level..Please try again...!!!"
        exit
fi
echo "The Eleventh level ends here & the exit status is $x"
#====  12th  level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Truncating storm topology"
	 ss_truncate_storm_topology
         x=`echo $?`
else
        echo "something does not look @ 11th level..Please try again...!!!"
        exit
fi
echo "The 12th level ends here & the exit status is $x"
#====  13th  level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Dumping storm topology"
	 ss_dump_storm_topology
         x=`echo $?`
else
        echo "something does not look @ 12th level..Please try again...!!!"
        exit
fi
echo "The 13th level ends here & the exit status is $x"
#====  14th  level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Loading storm topology"
	 ss_load_storm_topology
         x=`echo $?`
else
        echo "something does not look @ 13th level..Please try again...!!!"
        exit
fi
echo "The 14th level ends here & the exit status is $x"
#====  15th  level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Unlocking Db \"$DB"\"
	 unlock-database $DB
         x=`echo $?`
else
        echo "something does not look @ 14th level..Please try again...!!!"
        exit
fi
echo "The 15th level ends here & the exit status is $x"
#====  16th  level ====
if [ $x -eq 0 ]; then
         echo "============="
	 echo "Please find below list of Updated Databases"
	 list-dbs         
         x=`echo $?`
else
        echo "something does not look @ 15th level..Please try again...!!!"
        exit
fi
echo "The 16th level ends here & the exit status is $x"
#====  17th  level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Spot-checking..."
	 spot-check $DB
         x=`echo $?`
else
        echo "something does not look @ 16th level..Please try again...!!!"
        exit
fi
echo "The 17th level ends here & the exit status is $x"

echo "==========Restoration Completed Successfully...$DB was restored Successfully on $HOST==============="

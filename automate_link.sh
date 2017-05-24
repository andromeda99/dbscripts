#!/bin/bash

list-dbs () {
	psql -U postgres -c 'SELECT datname FROM pg_database;'
}
create-database () {	
	OWNER=niadmin

	if [[ "$HOST" =~ dev|qa && "$DATABASE" =~ socialsense|sla|staging|warehouse ]]; then
  	OWNER=niuser
	fi
	sudo -u postgres psql -c "CREATE DATABASE $DATABASE WITH OWNER $OWNER;"
}
clean-old-dumps () {
	echo 'Correcting permissions and removing files older than 12 hours...'
	sudo find /data/0/pg_backup \
	-type f  \
     	-mmin +$((60*12))  \
     	-exec rm -f {} \;
	sudo chgrp postgres /data/0/pg_backup/* /data/0/tmp /data/0/tmp/* 
	sudo chmod 777 /data/0/pg_backup/* /data/0/tmp /data/0/tmp/* /data/0/log /data/0/log/* 
}
restore-db () {
	HOST="$1"
	DATABASE="$DB"
	echo "HOST is $HOST"
	echo "DB is $DB"
	#access all other files relative to this script's directory.
	 cd "${0%/*}"
	
	if [ "$DATABASE" = "sla" ] || [ "$DATABASE" = "staging" ] || [ "$DATABASE" = "warehouse" ] ; then
	BACKUPS=$(ls /data/0/pg_backup/*"$DATABASE"*.pgdump)
	fi

	if [ "$DATABASE" = "qa1_staging" ] || [ "$DATABASE" = "staging_staging" ] ; then
	#BACKUPS=$(find '/data/0/pg_backup/*staging*.pgdump' -mmin "+${WAIT_FOR_TRANSFER}")
	BACKUPS=$(find /data/0/pg_backup/*staging*.pgdump)
	fi

	if [ "$DATABASE" = "qa1_warehouse" ] || [ "$DATABASE" = "staging_warehouse" ] ; then
	#BACKUPS=$(find '/data/0/pg_backup/*warehouse*.pgdump' -mmin "+${WAIT_FOR_TRANSFER}")
	BACKUPS=$(find /data/0/pg_backup/*warehouse*.pgdump)
	fi	

	if [[ "$DATABASE" = "socialsense" ]]; then
	#BACKUPS=$(find /data/0/pg_backup/*${DATABASE}*.pgdump -mmin "+${WAIT_FOR_TRANSFER}")
	BACKUPS=$(find /data/0/pg_backup/*${DATABASE}*.pgdump)
	#BACKUPS=$(find /pg_backup/${DATABASE}*.dump)
	fi

   	echo "Restoring ${DATABASE}..."

case "$HOST" in
        	qa1)
	           sudo -u postgres time /usr/pgsql-9.2/bin/pg_restore $BACKUPS | sed 's/niadmin/niuser/g' | /usr/pgsql-9.2/bin/psql -U postgres -d ${DATABASE}_new 1> /data/0/log/pg_restore_${DATABASE} 2>&1 >/dev/null
            ;;
	        staging2)
		sudo -u postgres time /usr/pgsql-9.2/bin/pg_restore $BACKUPS | /usr/pgsql-9.2/bin/psql -U postgres -d ${DATABASE}_new 1> /data/0/log/pg_restore_${DATABASE} 2>&1 >/dev/null
  	    ;;
        	dev1)
            	  sudo -u postgres time /usr/pgsql-9.2/bin/pg_restore $BACKUPS | sed 's/niadmin/niuser/g' | /usr/pgsql-9.2/bin/psql -U postgres -d ${DATABASE}_new 1> /data/0/log/pg_restore_${DATABASE} 2>&1 >/dev/null
            ;;
        	dev2)
            	sudo -u postgres time /usr/pgsql-9.2/bin/pg_restore $BACKUPS | sed 's/niadmin/niuser/g' | /usr/pgsql-9.2/bin/psql -U postgres -d ${DATABASE}_new 1> /data/0/log/pg_restore_${DATABASE} 2>&1 >/dev/null
            ;;
        	dev3)
            	sudo -u postgres time /usr/pgsql-9.2/bin/pg_restore $BACKUPS | sed 's/niadmin/niuser/g' | /usr/pgsql-9.2/bin/psql -U postgres -d ${DATABASE}_new 1> /data/0/log/pg_restore_${DATABASE} 2>&1 >/dev/null
            ;;
        	pentahodb-dev)
             	sudo -u postgres time /usr/pgsql-9.2/bin/pg_restore $BACKUPS | /usr/pgsql-9.2/bin/psql -U postgres -d ${DATABASE}_new 1> /data/0/log/pg_restore_${DATABASE} 2>&1 >/dev/null
            ;;
        *)
            echo $"Usage: $0 {qa|dev}"
            exit 1
esac
}
lock-database () {
DATABASE="$1"
		psql -U postgres -c "ALTER DATABASE $DATABASE CONNECTION LIMIT 0;"
}
kill-connection () {
	DATABASE="$1"
	pkill -f "$DATABASE" &
}
cutover () {
	DATABASE="$1"

	echo "Dropping ${DATABASE}_previous..."
	psql -U postgres -c "DROP DATABASE ${DATABASE}_previous;" 
	echo "Hello Db dropped"

	echo "Backing up ${DATABASE}..."
	psql -U postgres -c "ALTER DATABASE ${DATABASE} RENAME TO ${DATABASE}_previous;" 

	echo "Switching to new ${DATABASE}..."
	psql -U postgres -c "ALTER DATABASE ${DATABASE}_new RENAME TO ${DATABASE};"  
}

#====(Main) First level ====
HOST="$1"
DATABASE="$2"
DB=`echo $DATABASE | cut -d '_' -f 1`
echo "The host is $HOST"
echo  "Database selected for restoration is $DB "
x=`echo $?`
echo "The first level ends here & the exit status is $x"

#====  Second level ====
if [ $x == 0 ]; then 
	echo "========Please find below list of databases======="
	list-dbs
	x=`echo $?`	
	#echo "============="
else
	echo "something does not look @ first level..Please try again...!!!"
	exit
fi
echo "The Second level ends here & the exit status is $x"

#====  Third level ====
if [ $x -eq 0 ]; then
	echo "============="
	echo "Creating DB - $DB"
	create-database $HOST $DB
	x=`echo $?`
else
	echo "something does not look @ second level..Please try again...!!!"
        exit
fi
echo "The third level ends here & the exit status is $x"

#====  Fourth level ====
if [ $x -eq 0 ]; then
	echo "Database $DB created..."
	echo "============="
	echo "Cleaning old dumps....Please wait"
	clean-old-dumps 
	x=`echo $?`
else
        echo "something does not look @ third level..Please try again...!!!"
        exit
fi
echo $x
echo "The fourth level ends here & the exit status is $x"
#echo "As an exception below script will move further bcos above function Cleaning old dumps will need physicall files to check & this is a test environment."

#====  Fifth level ====
if [ $x -eq 0 ]; then
	echo "old dumps cleared...Please proceed further"
	echo "============="
	echo "Please find below list of updated DB"
	list-dbs
	x=`echo $?`
else
        echo "something does not look @ fourth level..Please try again...!!!"
        exit
fi
x=`echo $?`
echo "The fifth level ends here & the exit status is $x"
#====  Sixth level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Restoring DB - \"$DB"\"
         restore-db $HOST $DB
         x=`echo $?`
else
        echo "something does not look @ fifth level..Please try again...!!!"
        exit
fi
echo "The Sixth level ends here & the exit status is $x"
#====  Seventh level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Locking DB - \"$DB"\"
         lock-database $DB
         x=`echo $?`
else
        echo "something does not look @ sixth level..Please try again...!!!"
        exit
fi
echo "The Seventh level ends here & the exit status is $x"
#====  Eighth level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "kill-connections - \"$DB"\"
         kill-connection $DB
         x=`echo $?`	 
else
        echo "something does not look @ seventh level..Please try again...!!!"
        exit
fi
echo "The Eighth level ends here & the exit status is $x"
echo $x
#====  Ninth level ====
if [ $x -eq 0 ]; then
         echo "============="
         echo "Cutting Over - \"$DB"\"
         cutover $DB
         x=`echo $?`
else
        echo "something does not look @ Eighth level..Please try again...!!!"
        exit
fi

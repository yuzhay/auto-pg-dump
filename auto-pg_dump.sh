#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/auto-pg_dump.conf

NOW=$(date +"%Y-%m-%dT%H:%M:%S")

OS=$(uname -s)
case $OS in
  Darwin)
    DELETE_TIMESTAMP=`date -v-"$DELETE_AFTER"d +%s`
    ;;
  *)
    DELETE_TIMESTAMP=`date +%s --date="-$DELETE_AFTER days"`
    ;;
esac

IFS=',' read -ra DBS <<< "$PG_DATABASES"

echo " * Start databases backup";

for db in "${DBS[@]}"; do
  FILENAME="$db"_"$NOW"

  echo "   -> '$db' backing up..."
  pg_dump -Fc -h $PG_HOST -U $PG_USER -p $PG_PORT $db | gzip > /tmp/"$FILENAME".dump.gz

  mv /tmp/"$FILENAME".dump.gz "$BACKUP_PATH"/
  echo "      '$db' done"
done

echo " * Deleting old backups...";

ls $BACKUP_PATH | while read -r FILENAME;  do
  if [[ $FILENAME =~ _(20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}).dump(\.gz)?$ ]]; 
  then 
    DUMP_DATE=${BASH_REMATCH[1]}; 
  else 
    continue
  fi

  case $OS in
    Darwin)
      CREATE_TIMESTAMP=`date -jf '%Y-%m-%dT%H:%M:%S' "$DUMP_DATE" +%s`
      ;;
    *)
      CREATE_TIMESTAMP=`date +%s --date="$DUMP_DATE"`
      ;;
  esac

  if [[ $CREATE_TIMESTAMP -lt $DELETE_TIMESTAMP ]]
  then
    echo "   -> Deleting $FILENAME"
    rm -f $BACKUP_PATH/$FILENAME
  fi
done;

echo ""
echo " * Done";
echo ""
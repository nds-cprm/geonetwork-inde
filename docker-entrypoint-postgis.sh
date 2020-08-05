#!/bin/bash

set -e

if [ "$1" = 'catalina.sh' ]; then

    export CATALINA_HOME="${TOMCAT_NATIVE_LIBDIR}/../"
    echo "catalina home: $CATALINA_HOME"

	#Set geonetwork data dir
	export CATALINA_OPTS="$CATALINA_OPTS -Dgeonetwork.dir=$DATA_DIR"

    #Set data dir
	if [ ! -d "$DATA_DIR" ]; then
		echo "$Data directory '$DATA_DIR' does not exist. Creating it..."
		mkdir -p "$DATA_DIR"
	fi
	echo "data dir: $DATA_DIR"

	#Setting host
	db_host="${POSTGRES_DB_HOST:-postgis}"
	echo "db host: $db_host"

	#Setting port
	db_port="${POSTGRES_DB_PORT:-5432}"
	echo "db port: $db_port"

	#Setting database
	db_name="${POSTGRES_DB_NAME:-geonetwork}"
	echo "db name: $db_name"

    #Setting user and pass
	if [ -z "$POSTGRES_DB_USERNAME" ] || [ -z "$POSTGRES_DB_PASSWORD" ]; then
		echo >&2 "you must set POSTGRES_DB_USERNAME and POSTGRES_DB_PASSWORD"
		exit 1
	fi
	echo "db user $POSTGRES_DB_USERNAME"
	echo "db pass $POSTGRES_DB_PASSWORD"

	#Create databases, if they do not exist yet (http://stackoverflow.com/a/36591842/433558)
	touch ~/.pgpass && chmod 0600 ~/.pgpass
	echo  "$db_host:$db_port:*:$POSTGRES_DB_USERNAME:$POSTGRES_DB_PASSWORD" > ~/.pgpass
	if psql -h "$db_host" -p "$db_port" -U "$POSTGRES_DB_USERNAME" -tqc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1; then
		echo "Database '$db_name' exists; skipping createdb"
	elif psql -h "$db_host" -p "$db_port" -U "$POSTGRES_DB_USERNAME" -d "$db_name" -tqc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1; then
		echo "Database '$db_name' already exist; skipping database creation"
	else

echo  "$db_host:$db_port:*:$POSTGRES_USER:$POSTGRES_PASS" > ~/.pgpass
echo "Database '$db_name' doesn't exist. Creating it..."
psql -h "$db_host" -p "$db_port" -U "$POSTGRES_USER" -v ON_ERRO_STOP=1 <<-EOSQL
CREATE USER $POSTGRES_DB_USERNAME;
ALTER USER $POSTGRES_DB_USERNAME with encrypted password '$POSTGRES_DB_PASSWORD';
CREATE DATABASE $db_name;
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $POSTGRES_DB_USERNAME;
EOSQL

echo "Database '$db_name' now exist. Creating extensions it..."
psql -h "$db_host" -p "$db_port" -d "$db_name" -U "$POSTGRES_USER" -v ON_ERRO_STOP=1 <<-EOSQL
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
EOSQL

	fi
	rm ~/.pgpass

fi

#Write connection string for GN

# enable overwrite localhost

if [ ! -s "$CATALINA_HOME/webapps/geonetwork/WEB-INF/config-overrides-localhost.xml" ]; then

echo " sane for postgis. unknow why error from stylesheet in search.xsl"

sed -i -e 's/<xsl:variable name="langId">/<!--\n<xsl:variable name="langId">/; s/<\/xsl:stylesheet>/-->\n<\/xsl:stylesheet>/;' \
    "$CATALINA_HOME/webapps/geonetwork/xsl/metadata/common.xsl"

echo "creating config-overrides.html"

sed -i -e 's;\(</overrides>\);\t<override>/WEB-INF/config-overrides-localhost.xml</override>\n\1\n;' \
    "$CATALINA_HOME/webapps/geonetwork/WEB-INF/config-overrides.xml"

echo "creating config-overrides-localhost.html"

cat <<FEOF > "$CATALINA_HOME/webapps/geonetwork/WEB-INF/config-overrides-localhost.xml"
<?xml version="1.0" encoding="UTF-8"?>
<!-- look at config-overrides-example.xml -->
<overrides>

<properties>
    <enable>true</enable>
    <db.user>${POSTGRES_DB_USERNAME}</db.user>
    <db.pass>${POSTGRES_DB_PASSWORD}</db.pass>
    <db.name>${POSTGRES_DB_NAME}</db.name>
    <db.host>${POSTGRES_DB_HOST}</db.host>
    <db.port>${POSTGRES_DB_PORT}</db.port>
</properties>

<file name=".*/WEB-INF/config.xml">
    <replaceXML xpath="resources">
        <!-- posgresql -->
        <resource enabled="\${enable}">
            <name>main-db</name>
            <provider>jeeves.resources.dbms.ApacheDBCPool</provider>
            <config>
                <user>\${db.user}</user>
                <username>\${db.user}</username>
                <password>\${db.pass}</password>
                <driver>org.postgis.DriverWrapper</driver>
                <url>jdbc:postgresql_postGIS://\${db.host}:\${db.port}/\${db.name}</url>
                <poolSize>16</poolSize>
                <validationQuery>SELECT 1 </validationQuery>
            </config>
        </resource>
    </replaceXML>
</file>
</overrides>

FEOF

echo  "at $CATALINA_HOME/webapps/geonetwork/WEB-INF/config-overrides-localhost.xml"

fi

exec "$@"

#!/bin/bash

HELP="USAGE: . install_myApps.sh [options]\n
\n
OPTIONS:\n
\t    -c, --conda-home <PATH>             \t\t Path where Miniconda will be installed, or to an existing installation of Miniconda. Default is ~/miniconda.\n
\t    -env, --conda-env-name <NAME>         \t\t Name for conda environment. Default is 'myDjango'.\n
\t    --db-username <USERNAME>            \t\t Username that the database server will use. Default is 'tethys_default'.\n
\t    --db-password <PASSWORD>            \t\t Password that the database server will use. Default is 'pass'.\n
\t    --db-super-username <USERNAME>      \t Username for super user on the database server. Default is 'tethys_super'.\n
\t    --db-super-password <PASSWORD>      \t Password for super user on the database server. Default is 'pass'.\n
\t    --db-port <PORT>                    \t\t\t Port that the database server will use. Default is 5436.\n
\t    --db-dir <PATH>                     \t\t\t Path where the local PostgreSQL database will be created. Default is \${MYAPP_HOME}/psql.\n
\t    --install-geoserver                    \t\t\t Flag to install geoserver 
\t	-h|--help	\t\t\t\t Print this help information.\n
"

print_help()
{
    echo -e ${HELP}
    exit
}

set -e  # exit on error

# Set platform specific default options
if [ "$(uname)" = "Linux" ]
then
	MINICONDA_URL="https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh"
	BASH_PROFILE=".bashrc"
else
    echo $(uname) is not a supported operating system.
fi

# Set default options
#DB_USERNAME='db_default'
#DB_PASSWORD='pass'
#DB_SUPER_USERNAME='db_super'
#DB_SUPER_PASSWORD='pass'
#DB_PORT=5436
DB_DIR='psql'
CONDA_HOME=~/miniconda
CONDA_ENV_NAME='myApps'
MYAPP_HOME=~/.myApps
INSTALL_GEOSERVER=
GEOSERVER_USER="geoserver"
GEOSERVER_DB="geoserver"

# parse command line options
set_option_value ()
{
    local __option_key="$1"
    value="$2"
    if [[ $value == -* ]]
    then
        print_help
    fi
    eval $__option_key="$value"
}


while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-c|--conda-home)
		set_option_value CONDA_HOME "$2"
		shift # past argument
		;;
		-env|--conda-env-name)
		set_option_value CONDA_ENV_NAME "$2"
		shift # past argument
		;;

		--install-geoserver)
		INSTALL_GEOSERVER="true"
		;;
		-h|--help)
		print_help		
		;;
    esac
shift # past argument or value
done

if [ ! -d "$DIR" ]; then
  mkdir -p "${MYAPP_HOME}"
fi

if [ -f "${CONDA_HOME}/bin/activate" ]
then
    echo "Using existing Miniconda installation..."
else
	echo "Installing Miniconda..."
	# check if miniconda.sh already exist
	if [ ! -f "${MYAPP_HOME}/miniconda.sh" ]; then
		wget ${MINICONDA_URL} -O "${MYAPP_HOME}/miniconda.sh" || (echo -using curl instead; curl ${MINICONDA_URL} -o "${MYAPP_HOME}/miniconda.sh")
	fi	
    pushd ./
    cd "${MYAPP_HOME}"
    bash miniconda.sh -b -p "${CONDA_HOME}"
    popd
fi


source "${CONDA_HOME}/etc/profile.d/conda.sh"

#clone conda environment
conda activate
if [ ! -x "$(which git)" ]; then
	conda install --yes git
fi
if [ ! -f "${MYAPP_HOME}/myApps/environment.yml" ]; then
	git clone https://github.com/bikuz/myLinuxPackages.git "${MYAPP_HOME}/myApps"
fi

#create conda env and install packages
if [ "$(ls -A ${CONDA_HOME}/envs/${CONDA_ENV_NAME})" ]; then
     echo "using ${CONDA_ENV_NAME} environment"
else
    echo "Setting up the ${CONDA_ENV_NAME} environment..."
	conda env create -n ${CONDA_ENV_NAME} -f "${MYAPP_HOME}/myApps/environment.yml"
fi


conda activate ${CONDA_ENV_NAME}


####################################
# set default data directory
# ref: https://gist.github.com/gwangjinkim/f13bf596fefa7db7d31c22efd1627c7a
# https://www.youtube.com/watch?v=-LwI4HMR_Eg
# https://kb.objectrocket.com/postgresql/how-to-list-users-in-postgresql-782
# postgres command -> man psql
#       	   -> psql postgres ->enter into the database

if [ "$(ls -A ${MYAPP_HOME}/${DB_DIR})" ]; then
	echo "using ${DB_DIR}"
else
	mkdir ${MYAPP_HOME}/${DB_DIR}
	initdb -D ${MYAPP_HOME}/${DB_DIR}

	# configure pgsql as service to autorun after boot
	# remote connection to postgresql 
	#		http://devopspy.com/linux/allow-remote-connections-postgresql/

	# postgresql linux init.d script -> https://www.manniwood.com/2005_01_01/postgresql_startup_script_for_etcinitd.html
	# rename postgresql.conf & pg_hba.conf
	
	mv ${MYAPP_HOME}/${DB_DIR}/postgresql.conf ${MYAPP_HOME}/${DB_DIR}/postgresql_backup.conf
	mv ${MYAPP_HOME}/${DB_DIR}/pg_hba.conf ${MYAPP_HOME}/${DB_DIR}/pg_hba_backup.conf
	#copy file
	cp ${MYAPP_HOME}/myApps/postgresql_init.d/postgresql.conf ${MYAPP_HOME}/${DB_DIR}/postgresql.conf
	cp ${MYAPP_HOME}/myApps/postgresql_init.d/pg_hba.conf ${MYAPP_HOME}/${DB_DIR}/pg_hba.conf
	

	sudo chown $USER /etc/default
	PG_CONFIG=/etc/default/pgsql_service
	touch $PG_CONFIG

	echo "USER=${USER}" >> ${PG_CONFIG}
	echo "PG_INSTALL_DIR=${CONDA_HOME}/envs/${CONDA_ENV_NAME}" >> ${PG_CONFIG}
	echo "PG_DATA_DIR=${MYAPP_HOME}/${DB_DIR}" >> ${PG_CONFIG}
	echo "PG_SERVER_LOG=\$PG_DATA_DIR/serverlog" >> ${PG_CONFIG}
	echo "POSTGRES=\$PG_INSTALL_DIR/bin/postgres" >> ${PG_CONFIG}
	echo "PG_CTL=\$PG_INSTALL_DIR/bin/pg_ctl" >> ${PG_CONFIG}

	
	sudo chown $USER /etc/init.d
	cp ${MYAPP_HOME}/myApps/postgresql_init.d/pgsql_service /etc/init.d/pgsql_service
	
	
	
	
	
fi

if [ -f "/etc/init.d/pgsql_service" ]; then
	echo "Configuring postgresql ..."

	sudo chmod +x /etc/init.d/pgsql_service

	sudo systemctl daemon-reload
	sudo systemctl enable pgsql_service
	sudo systemctl start pgsql_service
	
	echo "PostgreSQL successfully configured at port:5432"	
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "For Remote Connection to PostgreSQL"
	echo "http://devopspy.com/linux/allow-remote-connections-postgresql"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "Steps to install pgadmin4 -> 'https://www.howtoforge.com/how-to-install-postgresql-and-pgadmin4-on-ubuntu-1804-lts'"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
fi

# INSTALL GEOSERVER
# https://gist.github.com/iacovlev-pavel/9006ba2f33cafc8d2ab71528f25f9f45
# https://www.youtube.com/watch?v=aLu8YbDg1Sg
# geoserver linux init.d script -> https://docs.geoserver.org/latest/en/user/production/linuxscript.html
# sudo chmod +x /etc/init.d/geoserver


if [ -n "${INSTALL_GEOSERVER}" ]; then
	echo 'installing java ...'
	conda install -c conda-forge openjdk=11
	#echo "export JAVA_HOME=${CONDA_HOME}/envs/${CONDA_ENV_NAME}" >> ~/.profile

	echo "installing unzip"
	sudo apt-get install unzip

	echo "installing geoserver"
	# restart db server
	pg_ctl -D ${MYAPP_HOME}/${DB_DIR} -l logfile restart
	
	echo "Set password for user 'geoserver' for psql"
	# create superuser on psql
	#createuser -s -P geoserver #ask to create password for user
	createuser -s geoserver
	createdb -O geoserver geoserver
	psql geoserver -c "CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology;"
	psql geoserver -c "ALTER USER geoserver WITH PASSWORD 'pass123';"

	sudo chown $USER /usr/share  # change permission to all other users
	mkdir -p /usr/share/geoserver
	cd 
	cd  /usr/share/geoserver

	wget http://sourceforge.net/projects/geoserver/files/GeoServer/2.17.0/geoserver-2.17.0-bin.zip
	unzip geoserver-2.17.0-bin.zip

	rm geoserver-2.17.0-bin.zip
	
	sudo chown $USER /etc/default
	GEO_CONFIG=/etc/default/geoserver
	touch $GEO_CONFIG

	echo "USER=${USER}" >> ${GEO_CONFIG}
	echo "GEOSERVER_DATA_DIR=/usr/share/geoserver/data_dir" >> ${GEO_CONFIG}
	echo "GEOSERVER_HOME=/usr/share/geoserver" >> ${GEO_CONFIG}
	echo "JAVA_HOME=${CONDA_HOME}/envs/${CONDA_ENV_NAME}" >> ${GEO_CONFIG}	
	echo "JAVA_OPTS=" >> ${GEO_CONFIG}
	
	sudo chown $USER /etc/init.d
	cp ${MYAPP_HOME}/myApps/geoserver_init.d/geoserver /etc/init.d/geoserver

	

	
	
	echo "GeoServer installed successfully"
	

	#mv geoserver-2.17.0/* .
	#echo "export GEOSERVER_HOME=/usr/share/geoserver" >> ~/.profile
	#. ~/.profile

	# GeoServer run
	#./bin/startup.sh
	
fi

if [ -f "/etc/init.d/geoserver" ]; then
	echo "Configuring geoserver ..."

	sudo chmod +x /etc/init.d/geoserver

	sudo systemctl daemon-reload
	sudo systemctl enable geoserver
	sudo systemctl start geoserver
	echo "GeoServer successfully configured at port:8080"	
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "GeoServer Username: admin"
	echo "Geoserver Password: geoserver"
	echo "GeoServer PostGIS Database: geoserver"
	echo "GeoServer PostGIS Database User: geoserver"
	echo "GeoServer PostGIS Dababase password: pass123"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"	
fi


# create shortcuts
SHORTCUT="alias run-myapps='source ${CONDA_HOME}/etc/profile.d/conda.sh; source ${MYAPP_HOME}/myApps/lib/myApps.sh; conda activate ${CONDA_ENV_NAME}'"
if grep -q "${SHORTCUT}" ~/${BASH_PROFILE}; then
	echo "Shortcuts already exist."
	. ~/${BASH_PROFILE}
else
	echo "# myApps Shortcuts" >> ~/${BASH_PROFILE}
	echo ${SHORTCUT} >> ~/${BASH_PROFILE}
	. ~/${BASH_PROFILE}
fi


echo "Deactivating the ${CONDA_ENV_NAME} environment..."
conda deactivate

###################################
# Essential Django pacakages
# https://opensource.com/article/18/9/django-packages
# https://vsupalov.com/favorite-django-packages-2019/



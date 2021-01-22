#!/bin/bash

DEFAULT_PORT=56453

declare -A PORTLIST

myapps(){
	case $1 in
		dbstart)
			sudo systemctl start pgsql_service			
			#pg_ctl -D ~/.myApps/psql -l ~/.myApps/psql/serverlog start
			;;
		dbstop)
			sudo systemctl stop pgsql_service
			#pg_ctl -D ~/.myApps/psql -l ~/.myApps/psql/serverlog stop
			;;
		dbrestart)
			sudo systemctl restart pgsql_service
			#pg_ctl -D ~/.myApps/psql -l ~/.myApps/psql/serverlog restart
			;;
		dbstatus)
			pg_ctl -D ~/.myApps/psql -l ~/.myApps/psql/serverlog status
			;;
		--dbmigrate)
			if [ ! -z "$2" ]; then
				__stopServer
				python $(pwd)/manage.py makemigrations $2
				python $(pwd)/manage.py migrate			
			else
				echo "--dbmigrate requires a name parameter"
			fi
			;;
		runserver)
			__stopServer
			curpath="$(pwd)"
			#echo $curpath/manage.py
			#fuser 56453/tcp
			__findUniquePort $curpath
			#PORTLIST[$DEFAULT_PORT]=$curpath
			#echo ${PORTLIST[$DEFAULT_PORT]}
			if [ -f "${curpath}/manage.py" ]; then			
				echo "http://localhost:$DEFAULT_PORT"		
				python manage.py runserver "localhost:$DEFAULT_PORT" & __runURL $DEFAULT_PORT			
			else
				echo "${curpath}/manage.py not found."
			fi		
			#OPEN NEW TERMINAL
			#gnome-terminal		
			;;
		stopserver)			
			__stopServer			
			;;
		-s|--start-project)
			if [ ! -z "$2" ]; then
				django-admin startproject $2
				python $(pwd)/$2/manage.py migrate
				echo "$(pwd)/$2"
				echo "Project created successfully."
			else
				echo "please specify project name"
			fi
			;;
		--add-mvc)
			if [ ! -z "$2" ]; then
				python $(pwd)/manage.py startapp $2
				touch $(pwd)/$2/urls.py
				echo "from django.urls import path" >> $(pwd)/$2/urls.py
				echo "from . import views" >> $(pwd)/$2/urls.py
			else
				echo "--add-mvc requires a name parameter"
			fi
			;;
		--createsuperuser)
			python $(pwd)/manage.py createsuperuser
			
	esac
}

__findUniquePort(){
	
	#loop until port is available
	while [ ! -z "$(lsof -t -i :$DEFAULT_PORT -s tcp:LISTEN)" ]
	do		
		if [ "${PORTLIST[$DEFAULT_PORT]}" == "$1" ]; then
			#PORT being used by same app
			echo "kill existing process"
			fuser -k $DEFAULT_PORT/tcp
			break			
		fi
		((DEFAULT_PORT++))
	done
	PORTLIST[$DEFAULT_PORT]=$1
}

__runURL(){
	pStarted=-1
	#echo "$pStarted"
	while [ $pStarted -le 0 ]
	do
		if [ ! -z "$(lsof -t -i :$1 -s tcp:LISTEN)" ]; then
			pStarted=1
			xdg-open "http://localhost:$1"
			#echo "done"
			
			break
		#else
			#echo "not done"
			#pStarted=2
		fi
		
	done
}

__stopServer(){
	fuser -k ${DEFAULT_PORT}/tcp
	echo "web server stopped."
}



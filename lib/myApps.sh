#!/bin/bash

if [ ! -x "$(which git)" ]; then
    echo "not found"
else
    echo "found"
fi

DEFAULT_PORT=56453

declare -A PORTLIST

myapps(){
	case $1 in
		dbstart)
			pg_ctl -D /home/bikuz/.myApps/psql -l /home/bikuz/.myApps/psql/serverlog start
			;;
		dbstop)
			pg_ctl -D /home/bikuz/.myApps/psql -l /home/bikuz/.myApps/psql/serverlog stop
			;;
		dbrestart)
			pg_ctl -D /home/bikuz/.myApps/psql -l /home/bikuz/.myApps/psql/serverlog restart
			;;
		runserver)
			curpath="$(pwd)"
			#echo $curpath/manage.py
			#fuser 56453/tcp
			findUniquePort $curpath
			#PORTLIST[$DEFAULT_PORT]=$curpath
			#echo ${PORTLIST[$DEFAULT_PORT]}
			if [ -f "${curpath}/manage.py" ]; then			
				echo "http://localhost:$DEFAULT_PORT"		
				python manage.py runserver "localhost:$DEFAULT_PORT" & runURL $DEFAULT_PORT			
			else
				echo "${curpath}/manage.py not found."
			fi		
			#OPEN NEW TERMINAL
			#gnome-terminal		
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
	esac
}

findUniquePort(){
	
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

getUniquePort(){
	#port=$((DEFAULT_PORT+0))
	
	
	while [ ! -z "${PORTLIST[$DEFAULT_PORT]}" ] #item in "${PORTLIST[@]}"
	do
		
		#echo ${PORTLIST[$DEFAULT_PORT]}
		if [ "${PORTLIST[$DEFAULT_PORT]}" == "$1" ]; then
			echo "${PORTLIST[$DEFAULT_PORT]}"
			#if [ -x "$(fuser DEFAULT_PORT/tcp)"]; then
				echo "kill process if exist"
				fuser -k $DEFAULT_PORT/tcp
			#fi	
			break
		else
			#lsof -Pi :$DEFAULT_PORT -s TCP:LISTEN -t >/dev/null
			if [ ! -z "$(lsof -t -i :$DEFAULT_PORT -s tcp:LISTEN)" ] ; then		
				((DEFAULT_PORT++))	
			else
				break
			fi		
		fi
	done
	echo "PORT: $DEFAULT_PORT is available."
}

runURL(){
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

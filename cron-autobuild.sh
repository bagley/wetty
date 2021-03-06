#!/bin/bash

# Remember to cd to this dir before running.
# 0 2 * * *   root   cd /path/to/wetty-repo && bash cron-autobuild.sh

config=cron-autobuild.conf
log=cron-autobuild.log
if ! [ -f $config ] ; then
	echo "Failed to find config file $config. Exiting"
	exit 1
fi
. $config
exit_code=0
echo > "$log"

if [ -n "$update_as_user" ] ; then
	su $update_as_user -c "bash autobuild.sh update" >> "$log" 2>&1
	exit_code=$(( $exit_code + $? ))
else
	bash autobuild.sh update >> "$log" 2>&1
	exit_code=$(( $exit_code + $? ))
fi

wetty_docker=wetty/Dockerfile
wetty_docker_saved=.cron
if ! [ -f $wetty_docker_saved ] ; then
	cp -a $wetty_docker $wetty_docker_saved
else
	if [ -n "$(diff -u $wetty_docker $wetty_docker_saved)" ] ; then
		diff -u $wetty_docker $wetty_docker_saved | mail -s "WeTTy repo's Dockerfile has changed" root
		rm -f $wetty_docker_saved
		cp -a $wetty_docker $wetty_docker_saved
	fi
fi

# only force rebuild (no cache) if image's age is in terms of weeks
force=""
if [ -n "$(docker images | grep "mydigitalwalk/wetty" | grep latest | grep weeks)" ] ; then
	force="-f"
fi

bash autobuild.sh publish $force -t >> "$log" 2>&1
exit_code=$(( $exit_code + $? ))

if [ $exit_code -eq 0 ] ; then
	msg="Successfully built and published wetty"
	if [ -z "$email" ] || [ "$email" == "always" ] ; then
		cat "$log" | mail -s "$msg" root
	fi
else
	msg="FAILED to build/publish wetty. Exit code $exit_code"
	cat "$log" | mail -s "$msg" root
fi

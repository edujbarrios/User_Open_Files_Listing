 

#############################################################

# @author: Eduardo José Barrios García
 # @Bbrief: This program, provides count of open files and oldest process for all logged-in users on a detrminate system where this code will be running.
 # Begin:
 
 ###########################################################

#!/bin/bash

# Declaring default variables
OFFLINE=0
USERS=()
FILTER="" #declaration of the filter gap 
CAPTURE_USERS=0
PROGNAME=$(basename $0);

# Function that outputs the help menu.
help_func() {
        echo "Usage: ${PROGNAME} [OPTIONS]";
        echo "This program, provides count of open files and oldest process for all logged-in users";
        echo;
        echo "Options:";
        echo  "\t-o, --off_line\t\tcheck offline users only";
        echo  "\t-f, --filter\t\tuse extended regex filter on open file count";
        echo  "\t-u [USERS]\t\tchecks provided users only";
        exit 0;
}

# Function that outputs the provided error, outputs help, then exits with 1. 
error_exit() {
        echo "${PROGNAME}: ${1:-"Unknown error"}" 1>&2
        echo;
        help_func;
        exit 1;
}

# Returns all unique users in order that are logged in.
logged_in_users() {
	# Grabs all users logged in and then sorts and gets the unique users only.
        who | awk '{print $1}' | sort | uniq | while read user; do
                uid=$(id -u $user);
                if [[ "${uid}" -ge 1000 ]]; then
                        echo "$user";
                fi; 
        done
}   

# Checks if the provided user is logged in or not. Returns 1 if they are logged in. 
check_user_online() {
	user="$1";
        users=$(logged_in_users);
	echo $users | while read o_user; do
		if [ "$o_user" == "$user" ]; then
			echo 1;
			return 1;
        	fi
        done
	echo 0;
	return 0;
}

# Return all users that are not currently logged in.
offline_users() {
	users=$(logged_in_users);
	# Grabs every user that is equal or less to 1000 (even though system daemons should be under 1000)
	awk -F: '$3 <= 1000 { print $1 }' /etc/passwd | while read user; do 
		user_online=$(check_user_online $user);
		if [ "$user_online" == "0" ]; then
			echo "$user";
		fi
	done
}

# Counts all open files by user, uses filter if provided. 
count_files() {
	user="$1";
	if [ -z "$FILTER" ]; then
		lsof -u $user | wc -l;
	else
		lsof -u $user | awk '{print $9}' | grep -E "${FILTER}" | wc -l; 
	fi
}

# Checking if the users provided while excecuting, exist.
check_users_exist() {
        printf "%s\n" "${USERS[@]}" | while read user; do
                id -u $user &>/dev/null;
                if [ "$?" -ne 0 ]; then
			echo $user;
			exit 1;
                fi
        done
}

# Primary function of script. 
main_function() {
        if [ "$OFFLINE" == 1 ]; then
                users=$(offline_users);
	elif [ ! -z "$USERS" ]; then
		users=$(printf "%s\n" "${USERS[@]}");
	        check=$(check_users_exist);
	        if [ ! -z "${check}" ]; then
        	        error_exit "The given user '$check', doesn't exist in this Personal Computer.";
	        fi
        else
                users=$(logged_in_users);
        fi
	if [ -z "$users" ]; then
		error_exit "There is no input given, or the provided users were not found, make sure to specify an existing user while excecuting this code.";
	fi
        if [ ! -z "$FILTER" ]; then
        	echo "Specifying the amount of files that contains this following filter: ${FILTER}";
		echo;
        fi
	
	# Iterates through all users in our users list. 
        echo "${users}" | while read user; do 
                file_count=$(count_files $user);
                uid=$(id -u $user);
                oldest_pid=$(pgrep -u $uid -o);
                echo "User: $user";
                echo "User ID: $uid";
                echo "Open Files: $file_count";
                echo "Oldest Process: ${oldest_pid:-None}";
                echo;
        done

}

# Disable globbing, we don't need regex filters to end up globbed. (which is a method that allows us to find files that we don't know the exact name), we unable this option until we need it in this code to avoid  unnecesary loadings.
set +o noglob

# Iterating through every argument provided.
for arg in "$@"; do
	case $1 in
		-h|--help)
			help_func;
			;;
		-o|--off_line)
			CAPTURE_USERS=0;
			OFFLINE=1;
			shift;
			;;
		-f|--filter)
			CAPTURE_USERS=0;
			FILTER="$2";
			shift;
			shift;
			;;
		-u)
			CAPTURE_USERS=1;
			shift;
			;;
		*)
			if [ $CAPTURE_USERS == 1 ]; then
				# Adds user to USERS list if CAPTURE_USERS is 1
				USERS+=("$1");
				shift;
			else
				# If there is unexpected input and it is not empty, error out. 
				if [ ! -z $1 ]; then
					error_exit "Unsupported option '$1'";
				fi
			fi
			;;
	esac
done
# Re-enable globbing. 
set -o noglob

# Call the main function.
main_function

# Dereferencing the used variables, no need to keep these active after script finishes.
unset OFFLINE;
unset USERS;
unset FILTER;
unset CAPTURE_USERS;

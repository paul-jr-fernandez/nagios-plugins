#!/bin/bash

#################################################################################
#Plugin name: check_all_procs.sh 						#
#Description: Plugin to monitor status of all specified processes		#
#Author: Paul Jr. Fernandez 							#
#################################################################################
#Usage: 								`	#
#./check_all_procs.sh -C <process_name1>:<min_frequency1>:<max_frequency1>	#
#################################################################################
#Change Log: 									#
#1.0: 2014-01-08 Paul Jr. Fernandez: Initial release 				#
#										#
#1.1: 2014-01-16 Paul Jr. Fernandez: Added check for processes that shouldn't	#
# be executed.									#
#										#
#1.2: 2014-01-16 Paul Jr. Fernandez: Added check for OpenVZ Hardware node	#
#                                                                               #
#################################################################################

#################################################################################
#Initializing Variables
#################################################################################

#Plugin Name
PLUGIN=$(basename $0)
#Plugin Version
VERSION=1.0
#Default Exit Status as UNKNOWN
EXIT_STATUS=3
#Current running processes
#Checking if server is OpenVZ Hardware Node
grep -q envID /proc/self/status
if [ $? -eq 0 ]
then
        PROCS_LIST=$(ps -q $(grep -sl "^envID:[[:space:]]*0\$" /proc/[0-9]*/status | sed -e 's#/proc/\([0-9]*\)/.*#\1#' | xargs | sed -e 's# #,#g') auwx | awk '{for (i=1; i<=NF-10; i++) $i = $(i+10); NF-=10; print}' | sort -k 1  | uniq -c )
else
        # For all other servers
        PROCS_LIST=$(ps auxw | awk '{for (i=1; i<=NF-10; i++) $i = $(i+10); NF-=10; print}' | sort -k 1  | uniq -c )
fi

#################################################################################
#Help Funtcions
#################################################################################

version(){
	echo "$PLUGIN Version $VERSION"
	exit $EXIT_STATUS
}

usage(){
	echo "Usage:"
	echo -e "$PLUGIN -C <process_name1>:<min_frequency1>:<max_frequency1> \n"
	echo -e "Options:\n-C\tSpecify process(es) to be monitored. For example:\n\t"./check_all_procs.sh -C httpd:1:1000 -C mysqld:1:100 -C ftpd:1:0 -C named:1:0"\n\tSpecify 0 if you do not want to set a threshold. In the above example, ftpd and named processes do not have an upper limit.\n-h\tPrint usage information\n-v\tPrint plugin version\n"
	echo -e "Example:\n./check_all_procs.sh -C httpd:1:1000 -C mysqld:1:100 -C ftpd:1:0 -C named:1:0"
	exit $EXIT_STATUS
}


#################################################################################
#Argument Handling
#################################################################################

CHECK_PROCS_THRESHOLD=()

while getopts ":C:hv" OPT
do
	case $OPT in
		v)
		version
		;;
		h)
		usage
		;;
		C)
		# Check whether the input is in a valid format
		if ! $( echo $OPTARG | grep -q "[a-Z]\+\(:[0-9]\+\)\{2\}" ); then
			echo "UNKNOWN: Incorrect Input Format."
			usage
		fi
		# Append the process and it's thresholds to a main array. Format ( "process" "min_freq" "max_freq" "actual_freq"). Actual frequency is initialised as 0.
		IFS=$' ' TEMP_PROCS_THRESHOLD=( $( echo $OPTARG | awk -F":" '{print $1,$2,$3}'))
		CHECK_PROCS_THRESHOLD=( "${CHECK_PROCS_THRESHOLD[@]}" "${TEMP_PROCS_THRESHOLD[@]}" "0")
#		for((i=0;i<${#CHECK_PROCS_THRESHOLD[@]};i+=4))
#		do
#			CHECK_PROCS_THRESHOLD[$i+3]=$(echo "$PROCS_LIST" | awk -v process="${CHECK_PROCS_THRESHOLD[$i]}" '$2 ~ process { sum+=$1;}END{if(sum){print sum}else{ print 0}}')
#		done
		;;
		:)
		echo -e "Option -$OPTARG requires an argument.\n"
		usage
		exit $EXIT_STATUS;
		;;
		\? ) echo -e "Unknown option: -$OPTARG \n" >&2
		usage
		exit $EXIT_STATUS;
		;;
	esac
done

# Check for case when no options was passed to plugin
if [ ${#CHECK_PROCS_THRESHOLD[@]} -eq 0 ]
then
	echo -e "Plugin requires arguments to function. Please read usage instructions detailed below.\n"
	usage
	exit $EXIT_STATUS;
fi


#################################################################################
#MAIN
#################################################################################

# Initializing Warning and Critical Arrays as NULL

WARNING=()
CRITICAL=()

# Traversing "CHECK_PROCS_THRESHOLD" array which contains the list of relevant processes along with min max and actual frequency.
for((i=0;i<${#CHECK_PROCS_THRESHOLD[@]};i+=4))
do
	# Calculate actual frequency of process in process list
	#CHECK_PROCS_THRESHOLD[$i+3]=$(echo "$PROCS_LIST" | awk -v process=${CHECK_PROCS_THRESHOLD[$i]}"$" '$2 ~ process { sum+=$1;}END{if(sum){print sum}else{ print 0}}')
	CHECK_PROCS_THRESHOLD[$i+3]=$(echo "$PROCS_LIST" | awk -v process=${CHECK_PROCS_THRESHOLD[$i]}"$" '{for (i=2; i<=NF; i++){ if (match( $i, process)) { sum+=$1;}}}END{if(sum){print sum}else{ print 0}}')
	# Checking for processes that should not be running
	if [ ${CHECK_PROCS_THRESHOLD[$i+1]} -eq 0 ] && [ ${CHECK_PROCS_THRESHOLD[$i+2]} -eq 0 ] && [ ${CHECK_PROCS_THRESHOLD[$i+3]} -gt 0 ] 
	then
		CRITICAL=( "${CRITICAL[@]}" "${CHECK_PROCS_THRESHOLD[$i]}" "${CHECK_PROCS_THRESHOLD[$i+1]}" "${CHECK_PROCS_THRESHOLD[$i+3]}" )
	fi
	# Checking whether actual frequency is less than minimum frequency threshold
	if [ ${CHECK_PROCS_THRESHOLD[$i+1]} -ne 0 ] && [ ${CHECK_PROCS_THRESHOLD[$i+3]} -lt ${CHECK_PROCS_THRESHOLD[$i+1]} ]
	then
		CRITICAL=( "${CRITICAL[@]}" "${CHECK_PROCS_THRESHOLD[$i]}" "${CHECK_PROCS_THRESHOLD[$i+1]}" "${CHECK_PROCS_THRESHOLD[$i+3]}" )
	fi
	# Checking whether actual frequency is more than maximum frequency threshold
	if [ ${CHECK_PROCS_THRESHOLD[$i+2]} -ne 0 ] && [ ${CHECK_PROCS_THRESHOLD[$i+3]} -gt ${CHECK_PROCS_THRESHOLD[$i+2]} ]
	then
		WARNING=( "${WARNING[@]}" "${CHECK_PROCS_THRESHOLD[$i]}" "${CHECK_PROCS_THRESHOLD[$i+2]}" "${CHECK_PROCS_THRESHOLD[$i+3]}" )
	fi
done

#################################################################################
#Output Formatting
#################################################################################


# Checking if Critical Array has contents.
if [ ${#CRITICAL[@]} -ne 0 ]
then
	EXIT_STATUS=2
	echo -n "CRITICAL: "
	for((i=0;i<${#CRITICAL[@]};i+=3))
	do
		# Status message for processes that are not supposed to run
		if [ ${CRITICAL[$i+1]} -eq 0 ]
		then
			echo -n ${CRITICAL[$i]}":" ${CRITICAL[$i+2]} "process(es) running." ${CRITICAL[$i]} "is not supposed to run."
		else
			# Status message for processes that are less than minimum required
			echo -n ${CRITICAL[$i]}":" ${CRITICAL[$i+2]} "process(es) running. Minimum required is" ${CRITICAL[$i+1]} "process(es). "
		fi
	done
	# Checking if Warning Array has contents.
	if [ ${#WARNING[@]} -ne 0 ]
	then
		# Status message for processes that are more than the maximum expected
		for((j=0;j<${#WARNING[@]};j+=3))
		do
			echo -n ${WARNING[$j]}":" ${WARNING[$j+2]} "process(es) running. Maximum allowed is" ${WARNING[$j+1]} "process(es). "
		done
	fi
	echo ""
# Checking if ONLY Warning Array has contents.
elif [ ${#WARNING[@]} -ne 0 ]
then
	echo -n "WARNING: "
	EXIT_STATUS=1
	# Status message for processes that are more than the maximum expected
	for((j=0;j<${#WARNING[@]};j+=3))
	do
		echo -n ${WARNING[$j]}":" ${WARNING[$j+2]} "process(es) running. Maximum allowed is" ${WARNING[$j+1]} "process(es). "
	done
	echo ""
else
	# Status message if all processes are executing within provided thresholds
	echo "OK: All processes are within limits."
	EXIT_STATUS=0
fi

exit $EXIT_STATUS

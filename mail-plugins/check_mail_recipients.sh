#!/bin/bash

#################################################################
#Plugin name:check_mail_recipients.sh                  		#
#Description:Plugin to monitor failing recipients in mail queue #
#Author:Paul Jr. Fernandez                           		#
#################################################################
#Usage:								#
#./check_mail_recipients.sh					#
#################################################################
#Change Log:							#
#1.0: 2013-04-23	Paul Jr. Fernandez	Initial release	#
#								#
#1.1: 2013-06-20	Paul Jr. Fernandez	Removed script's#
#reliance on temporary files.					#
#								#
#2.0: 2014-08-22	Paul Jr. Fernandez	Removed reliance#
#on arrays and array functions. Added version and help messages.#
#Added argument handling.					#
#################################################################

#################################################################
#Initializing Variables
#################################################################

#Plugin Name
PLUGIN=$(basename $0)
#Plugin Version
VERSION=2.0
#Default Exit Status as UNKNOWN
EXIT_STATUS=3
#Assign absolute path of mailq command
MAILQ=$(which mailq)
#Initializing Warning and Critical strings as NULL
WARNING_MAILIDS=""
CRITICAL_MAILIDS=""
#Argument Flags
FLAG_W=0
FLAG_C=0

#################################################################
#Help Funtcions
#################################################################

version(){
	echo "$PLUGIN Version $VERSION"
	exit $EXIT_STATUS
}

usage(){
	echo "Usage:"
	echo "$PLUGIN -w <warn frequency> -c <crit frequency>"
	echo -e "Options:\n-h\n\tPrint usage information\n-w\n\tEmail id frequency to result in warning status\n-c\n\tEmail id frequency to result in critical status"
	exit $EXIT_STATUS
}

#################################################################
#Argument Handling
#################################################################

while getopts ":w:c:hv" OPT
do
        case $OPT in
		v)
		version
		;;
                h)
                usage
                ;;
                w)
                WARNING_THRESHOLD=$OPTARG;
		FLAG_W=1
                ;;
                c)
                CRITICAL_THRESHOLD=$OPTARG;
		FLAG_C=1
                ;;
                :)
                echo "Option -$OPTARG requires an argument."
		exit $EXIT_STATUS;
                ;;
		\? ) echo "Unknown option: -$OPTARG" >&2
		usage
		exit $EXIT_STATUS;
		;;
        esac
done

#Checking for mandatory arguments

if [ $FLAG_C -ne 1 ] || [ $FLAG_W -ne 1 ];then
	if [ $FLAG_C -eq 1 ];then
		echo "Missing option: -w <warn frequency>"
		usage
	elif [ 	$FLAG_W -eq 1 ];then
		echo "Missing option: -c <crit frequency>"
		usage
	else
		echo "Missing options: -w <warn frequency> -c <crit frequency>"
		usage
	fi
fi

#################################################################
#Parsing the output of mailq and retrieving recipients list. 
#Also, when done will have calculate the frequency of each 
#recepient in the mailq
#TO_ADDRESS will store email ids in ascending order of frequency
#################################################################

TO_ADDRESS=$( $MAILQ | awk '( $1 ~ /@/ ) {print $1}' | sort | uniq -c | sort -n)

#################################################################
#Assigning recipients to appropriate variables based on the 
#thresholds specified
#WARNING_MAILIDS: email ids that trip the warning threshold
#CRITICAL_MAILIDS: email ids that trip the critical threshold
#################################################################

WARNING_MAILIDS=$(echo "$TO_ADDRESS" | awk -v w="${WARNING_THRESHOLD}" -v c="${CRITICAL_THRESHOLD}" '( $1 >= w && $1 < c ) {printf("%s | ", $2)}')
CRITICAL_MAILIDS=$(echo "$TO_ADDRESS" | awk -v c="${CRITICAL_THRESHOLD}" '( $1 >= c ) {printf("%s | ", $2)}')

#################################################################
#Determining the status code
#################################################################

if [[ ! -z $CRITICAL_MAILIDS ]];then
	echo -n "CRITICAL: "
	EXIT_STATUS=2
elif [[ ! -z $WARNING_MAILIDS ]];then
	echo -n "WARNING: "
	EXIT_STATUS=1
else
	echo -n "OK: No email addresses have crossed the threshold"
	EXIT_STATUS=0
fi

#################################################################
#Generating output message
#################################################################

if [[ ! -z $CRITICAL_MAILIDS ]];then
	echo -n "More than 250 mails in queue: $CRITICAL_MAILIDS "
fi
if [[ ! -z $WARNING_MAILIDS ]];then
	echo  -n "More than 100 mails in queue: $WARNING_MAILIDS "
fi

echo -ne "\n"

if [ $EXIT_STATUS -eq 3 ]; then
	echo "UNKNOWN: Problems were encountered during the execution of the script"
fi

exit $EXIT_STATUS

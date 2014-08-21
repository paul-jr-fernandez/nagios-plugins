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
#1.1: 2013-06-20	Paul Jr. Fernandez	Removed scripts	#
#reliance on temporary files.					#
#                                                               #
#################################################################

#################################################################
#Initializing all arrays as empty
#################################################################

#Recipients in mail queue
to_address=()
#Frequency of recipients in mail queue
count=()
#Recipients that have crossed critical threshold
critical=()
#Recipients that have crossed warning threshold
warning=()
#Flag for exit status of plugin
flag=0
#Flag for checking whether email address has already been parsed
#(ie, it is present in the "to_address" array)
present=0

#################################################################
#Parsing the output of mailq and retrieving recipients list. 
#Also, when done will have calculate the frequency of each 
#recepient in the mailq
#################################################################

while read line; do
        if [[ "$( echo $line | awk '{print $1}' )" == *@* ]]; then
                present=0
                id=$( echo $line | awk '{print $1}' )
                for(( i=0; i<${#to_address[@]}; i++ ))
                do
                        if [[ "$id" == ${to_address[$i]} ]]; then
                                count[$i]=$(( ${count[$i]}+1 ))
                                present=1
                        fi
                done
                if [ $present == 0 ]; then
                        to_address=( "${to_address[@]}"  $id )
                        count[$i]=1
                fi
        fi
done <<< "`/usr/bin/mailq`"

#################################################################
#Assigning recipients into appropriate arrays based on the 
#thresholds specified
#################################################################

for(( i=0; i<${#to_address[@]}; i++ ))
do
	if [[ ${count[$i]} -gt 250 ]]; then
		flag=2
		critical=( "${critical[@]}"  ${to_address[$i]} )
	elif [[ ${count[$i]} -gt 100 ]]; then
		if [[ flag -ne 2 ]]; then
			flag=1
		fi
		warning=( "${warning[@]}"  ${to_address[$i]} )
	else
		continue
	fi
done

#################################################################
#Determining the status code
#################################################################

if [[ $flag == 2 ]]; then
	echo -n "CRITICAL: "
elif [[ $flag == 1 ]]; then
	echo -n "WARNING: "
else
	echo -n "OK: No email addresses have crossed the threshold"
fi

#################################################################
#Generating output message
#################################################################

if [[ ${#critical[@]} -ne 0 ]]; then
	echo -n "More than 250 mails in queue: ${critical[@]}.	"
fi
if [[ ${#warning[@]} -ne 0 ]]; then
	echo  -n "More than 100 mails in queue: ${warning[@]}."
fi

echo -ne "\n"

exit $flag


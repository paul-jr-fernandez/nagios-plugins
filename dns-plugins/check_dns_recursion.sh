#!/bin/bash
#################################################################			
#Plugin name:check_dns_recursion.sh                             #
#Description:Plugin to check if  DNS servers allow recursion   	#
#Author:Paul Jr. Fernandez                                      #
#################################################################
#Usage:								#
#./check_dns_recursion -H <hostname>				#
#################################################################
#Change Log:							#
#1.0: 2014-12-23	Paul Jr. Fernandez	Initial release	#
#								#
#1.1: 2014-08-16	Paul Jr. Fernandez	Added exception	#
#for cases when the provided host is not a DNS server.		#
#                                                               #
#################################################################

#Argument Handling

# Checking syntax; see Usage section above
if [ "$1" != "-H" ]; then

	# Checking for help message parameters
	if [ "$1" != "-h" ] && [ "$1" != "--help" ]; then
		echo "Incorrect Syntax"
	else
		echo  -e "Usage:\n./check_dns_recursion -H <hostname>"
		echo -e "-H\tHostname. Should be followed with the hostname of the DNS Server"
	fi	#End of Help Message

# Only if syntax is correct, will control proceed
else
	#Variable for signifying recursive nature; 0 for non-recursive and 1 for recursive
	recursion=0 	

	#Flags begin from the third column; hence index is initialized as 3
	index=3	

	#Retrieve the first flag returned by DNS query
	flag=$( dig google.com @$2 +noall +comments |sed -n '6p' | awk -v i=$index '{print $i}')

	#Condition to check for incorrect DNS servers
	if [[ -z $flag ]];then
		echo "UNKNOWN: $2 does not seem to be a DNS server. Please verify and try again."
		exit 3
	fi

	#While condition set to check till the last flag
	while [ "$flag" != "QUERY:" ] 
	do

		#If condition to check whether the retrieved flag value is ra(Recursive Allowed)
		if [[  "$flag" = ra* ]]; then
			recursion=1
			break
		fi
	
		#Increment "index" and retrieve subsequent flags
		index=$(( $index + 1 ))
		flag=$(dig google.com @$2 +noall +comments |sed -n '6p' | awk -v i=$index '{print $i}')
	done
	
	#Check final value of the variable "recursion" to determine whether the server is recursive or not
	if [ $recursion -eq 1 ]; then
		echo "WARNING: $2 is an Open Recursive DNS Server"
		exit 1
	else
		echo "OK: $2 is not an Open Recursive DNS Server"
		exit 0
	fi
fi	#End of Argument Handling

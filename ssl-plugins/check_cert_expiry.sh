#!/bin/bash
# 
#################################################################
#Plugin name:check_ssl_cert_expiry.sh 				#
#Description:Plugin to identify domains with soon to expire	#
# SSL certificates						#
#Author:Paul Jr. Fernandez 					#
#################################################################
#Usage: 							#
#./check_ssl_cert_expiry.sh [-OPTIONS] 				#
#################################################################
#Change Log: 							#
#1.0: 2015-03-16 Paul Jr. Fernandez Initial release 		#
#1.1: 2015-03-17 Paul Jr. Fernandez Corrected RE that checks	#
#	the format of provided "hostname:ports". Wrote code to  #
#       handle wrong SSL site input.                           	#
# 								#
#################################################################

#################################################################
#Initializing Variables
#################################################################
#Plugin Name
PLUGIN=$(basename $0)
#Plugin Version
VERSION=1.0

INCORRECT_INPUT=( )
WARN_EXPIRY=( )
CRIT_EXPIRY=( )
EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNKNOWN=3
EXIT_STATUS=$EXIT_UNKNOWN
HOSTNAME=""
FILE="/dev/null"

#################################################################
#Help Funtcions
#################################################################

version(){
echo "$PLUGIN Version $VERSION"
exit $EXIT_STATUS
}

usage(){
echo "Usage:"
echo "$PLUGIN -[OPTIONS]"
echo -e "Options:\n-h\n\tPrint usage information\n-f\n\tFile that contains server list information in the format-> www.paul.com:443\n-H\n\tDomain name and port in the following format-> www.paul.com:443"
exit $EXIT_STATUS
}

#################################################################
#Argument Handling
#################################################################

while getopts ":H:f:hv" OPT
do
	case $OPT in
	v)
	version
	;;
	h)
	usage
	;;
	H)
	if ! $( echo $OPTARG | grep -q '^\([A-Za-z0-9-]\+\.\)\?[A-Za-z0-9-]\+\.[A-Za-z]\+\:[0-9]\+$' ); then
		echo "UNKNOWN: Incorrect Input Format."
		usage
	fi
        HOSTNAME=$OPTARG;
	;;
	f)
	FILE=$OPTARG;
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

if [ -f $FILE ];then
	for SERVER in $(cat $FILE)
	do
		if $( echo $SERVER | grep -q '^\([A-Za-z0-9-]\+\.\)\?[A-Za-z0-9-]\+\.[A-Za-z]\+\:[0-9]\+$' );
		then
			NOT_AFTER=$(openssl s_client -connect $SERVER < /dev/null 2>/dev/null | openssl x509 -text -noout 2>/dev/null | awk '$1 ~ /Not/ && $2 ~ /After/ { $1=$2=$3=""; print}' | sort | uniq |  sed -e 's/^[[:space:]]*//')  
			if [[ -z $NOT_AFTER ]];
			then
				INCORRECT_INPUT=( "${INCORRECT_INPUT[@]}" "$SERVER")
			else
				TIME_2_EXPIRY=$(( $(date +%s --date="$NOT_AFTER") - $(date +%s) ))
				if [ $TIME_2_EXPIRY -lt 1209600 ];
				then
					if [ $TIME_2_EXPIRY -lt 604800 ];
					then
						CRIT_EXPIRY=( "${CRIT_EXPIRY[@]}" "$SERVER" )
					else
						WARN_EXPIRY=( "${WARN_EXPIRY[@]}" "$SERVER" )
					fi
				fi
			fi
		else
			INCORRECT_INPUT=( "${INCORRECT_INPUT[@]}" "$SERVER")
		fi
	done
elif ! [ -z $HOSTNAME ];
then
	NOT_AFTER=$(openssl s_client -connect $HOSTNAME < /dev/null 2>/dev/null | openssl x509 -text -noout 2>/dev/null | awk '$1 ~ /Not/ && $2 ~ /After/ { $1=$2=$3=""; print} ' | sort | uniq |  sed -e 's/^[[:space:]]*//')
	if [[ -z $NOT_AFTER ]];	
	then
		echo -n "UNKNOWN: Unable to load certificate for $HOSTNAME"
		EXIT_STATUS=$EXIT_UNKNOWN
		echo ""
		exit $EXIT_STATUS
	else
		TIME_2_EXPIRY=$(( $(date +%s --date="$NOT_AFTER") - $(date +%s) ))
		if [ $TIME_2_EXPIRY -lt 1209600 ];
		then
			if [ $TIME_2_EXPIRY  -lt 604800 ];
			then
				echo -n "CRITICAL: $HOSTNAME uses a certificate that will expire in $(( $TIME_2_EXPIRY/86400 )) days."
				EXIT_STATUS=$EXIT_CRIT
			else
				echo -n "WARNING: $HOSTNAME uses a certificate that will expire in $(( $TIME_2_EXPIRY/86400 )) days."
				EXIT_STATUS=$EXIT_WARN	
			fi
		fi
	fi
fi

if [ ${#CRIT_EXPIRY[@]} -ne 0 ];
then
	EXIT_STATUS=$EXIT_CRIT
	echo -n "CRITICAL: "
	printf " %s," "${CRIT_EXPIRY[@]}" | cut -d "," -f 1-${#CRIT_EXPIRY[@]} | awk '{printf $0}'
	echo -n " use(es) certificate(s) that will expire in less than a week."
elif [ ${#WARN_EXPIRY[@]} -ne 0 ];
then
	if [ $EXIT_STATUS -ne $EXIT_CRIT ];
	then
		EXIT_STATUS=$EXIT_WARN
		echo -n "WARNING: "
	fi
	printf " %s," "${WARN_EXPIRY[@]}" | cut -d "," -f 1-${#WARN_EXPIRY[@]} | awk '{printf $0}'
	echo -n " use(es) certificate(s) that will expire in less than a fortnight."
fi

if [ $EXIT_STATUS -eq $EXIT_UNKNOWN ];
then
        echo -n "OK: No upcoming expiry dates for SSL Certificates."
        EXIT_STATUS=$EXIT_OK
fi

if [ ${#INCORRECT_INPUT[@]} -ne 0 ];
then
	echo -n " Please re-check the following input strings(either wrong format or not a valid SSL site):"
	printf "  %s," "${INCORRECT_INPUT[@]}" | cut -d "," -f 1-${#INCORRECT_INPUT[@]} | awk '{printf $0}'
	echo ""
	exit $EXIT_STATUS
fi

echo ""
exit $EXIT_STATUS

#!/bin/bash
# 
#################################################################
#Plugin name:check_ssl_cert_algo.sh 				#
#Description:Plugin to identify domains that have certificates 	#
#that use the outdate algorithm "sha1WithRSAEncryption"		#
#Author:Paul Jr. Fernandez 					#
#################################################################
#Usage: 							#
#./check_ssl_cert_algo.sh [-OPTIONS] 				#
#################################################################
#Change Log: 							#
#1.0: 2015-03-16 Paul Jr. Fernandez Initial release 		#
#1.1: 2015-03-17 Paul Jr. Fernandez Corrected RE that checks	#
#	the format of provided "hostname:ports". Wrote code to	#
#	handle wrong SSL site input.				#
# 								#
#################################################################

#################################################################
#Initializing Variables
#################################################################

# Initialize

#Plugin Name
PLUGIN=$(basename $0)
#Plugin Version
VERSION=1.0

INCORRECT_INPUT=( )
WARN_ALGO=( )
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
	if ! $( echo $OPTARG | grep -q '^\([A-Za-z0-9-]\+\.\)\?[A-Za-z0-9-]\+\.[A-Za-z]\+\:[0-9]\+$' ); 
	then
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
			SIGN_ALGO=$(openssl s_client -connect $SERVER < /dev/null 2>/dev/null | openssl x509 -text -noout 2>/dev/null | awk '$1 ~ /Signature/ && $2 ~ /Algorithm/{$1=$2=""; print}' | sort | uniq |  sed -e 's/^[[:space:]]*//')
			if [[ $SIGN_ALGO == "sha1WithRSAEncryption" ]];
			then
				WARN_ALGO=( "${WARN_ALGO[@]}" "$SERVER" )
			elif [ -z $SIGN_ALGO ];
			then
				INCORRECT_INPUT=( "${INCORRECT_INPUT[@]}" "$SERVER")
			fi
		else
                        INCORRECT_INPUT=( "${INCORRECT_INPUT[@]}" "$SERVER")
		fi
	done
elif ! [ -z $HOSTNAME ];
then
	SIGN_ALGO=$(openssl s_client -connect $HOSTNAME < /dev/null 2>/dev/null | openssl x509 -text -noout 2>/dev/null | awk '$1 ~ /Signature/ && $2 ~ /Algorithm/ {$1=$2=""; print}' | sort | uniq |  sed -e 's/^[[:space:]]*//')
	if [[ $SIGN_ALGO == "sha1WithRSAEncryption" ]];
	then
		echo -n "WARNING: $HOSTNAME uses outdated algorithm sha1WithRSAEncryption."
		EXIT_STATUS=$EXIT_WARN
	elif [ -z $SIGN_ALGO ];
	then
		echo -n "UNKNOWN: Unable to load certificate for $HOSTNAME"
		EXIT_STATUS=$EXIT_UNKNOWN
		echo ""
		exit $EXIT_STATUS
	fi
fi

if [ ${#WARN_ALGO[@]} -ne 0 ];
then
   	EXIT_STATUS=$EXIT_WARN
   	echo -n "WARNING: "
	printf " %s," "${WARN_ALGO[@]}" | cut -d "," -f 1-${#WARN_ALGO[@]} | awk '{printf $0}' 	
	echo -n " use(es) an outdated Signature Algorithm."
fi

if [ $EXIT_STATUS -ne $EXIT_WARN ];
then
        echo -n "OK: All SSL certificates use updated Signature Algorithm."
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

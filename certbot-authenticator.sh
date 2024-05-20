#!/bin/bash

# Temp dir where we store our files as we execute
TMPDIR=/tmp/zoneedit/$CERTBOT_DOMAIN

# Path to config file
CONFIG=/etc/sysconfig/zoneedit.cfg

# File to store cookies and read them back between each curl call
COOKIES=$TMPDIR/cookies.txt

# No debug by default - -D enables this
DEBUG=""

# No verbose by default - -V enabled this
VERBOSE=""

# Output enabled by default (disable with -Q switch)
ENABLE_OUTPUT=1

# We start new session unless -k specified
ZAP=1

# No dry run by default
DRYRUN=""

# No clean by default
CLEAN=0

# Run a curl command
# Usage:
#   CURL url output [data]
# Where:
#      url     is the URL to connect to
#      output  is the prefix of the file to save output to in $TMPDIR
#              this will create 3 files: $output.html - stdout - or html source
#                                        $output.stderr - stderr - or curl status output
#                                        $outut.header - the headers returned from the request

CURL() {
	local URL=$1
	local OUT=$2
	shift 2
	local DATA=$@
	local CMD="curl --user $ZONEEDIT_USER:$ZONEEDIT_PASS -D $TMPDIR/$OUT.header $DATA $URL"
	if [ -f $TMPDIR/$OUT.html ] ; then
		if [ $DEBUG ] ; then
			echo "Found $OUT.htnl. Not running '$CMD' > $TMPDIR/$OUT.html 2> $TMPDIR/$OUT.stderr"
		fi
	else
		if [ $DEBUG ] ; then
			echo "Running $CMD 2> $TMPDIR/$OUT.stderr | sed -e \"s/>/>\\n/g\" > $TMPDIR/$OUT.html"
		elif [ $VERBOSE ] ; then
			echo "$URL"
		fi
		$CMD 2> $TMPDIR/$OUT.stderr | sed -e "s/>/>\\n/g" > $TMPDIR/$OUT.html
	fi
}

# Usage of script
# This is called on error or as part of a "-h" (help) argument
Usage() {
	echo "USAGE: $0 [-h] [-k] [-D] [-V] [-Q] -d domain -n name -v value [-t ttl] [-i id]"
	if [ "$1" = "" ] ; then
		echo "WHERE:"
		echo "      -h         Show this help output."
		echo "      -k         Do not Zap the contents of tmpdir before starting to start new session. Instead re-use existing session files."
		echo "      -D         Enable debug output (WARNING: Password output to stdout)."
		echo "      -V         Enable verbose output."
		echo "      -Q         Disable all output (quiet mode)."
		echo "      -R         Do just a dry run and do not change anything on Zoneedit domain."
		echo "      -d domain  Specify the domain to manage (required)."
		echo "      -n name    Specify the name of the TXT record to edit (required)."
		echo "      -v value   Specify the value of the TXT record to edit (require)."
		echo "      -t ttl     Specify time to live in seconds (optional - default 60)."
		echo "      -i id      Specify ID of TXT record to edit (optional - default 0)."
		echo "      -c         Cleanup (delete old TXT record)."
	else
		echo "ERROR: $@"
		exit 1
	fi
	exit
}

# Output message to console with timestamp
output() {
	if [ $ENABLE_OUTPUT ] ; then
		echo "`date`: $@"
	fi
}

# Default time to live is 60 seconds
txt_ttl=60
# Default record ID is the first one (#0) - should be 0, 1, 2, 3, 4.. etc
txt_id=0

# Extract any passed in arguments
while [ $# -gt 0 ] ; do
	if [ "$1" = "-h" -o "$1" = "-?" -o "$1" = "--help" ] ; then
		Usage
	elif [ "$1" = "-D" ] ; then
		DEBUG=1
		VERBOSE=1
	elif [ "$1" = "-V" ] ; then
		VERBOSE=1
	elif [ "$1" = "-Q" ] ; then
		ENABLE_OUTPUT=
	elif [ "$1" = "-R" ] ; then
		DRYRUN=1
	elif [ "$1" = "-d" ] ; then
		shift
		txt_domain=$1
	elif [ "$1" = "-n" ] ; then
		shift
		txt_name=$1
	elif [ "$1" = "-v" ] ; then
		shift
		txt_value=$1
	elif [ "$1" = "-t" ] ; then
		shift
		txt_ttl=$1
	elif [ "$1" = "-i" ] ; then
		shift
		txt_id=$1
	elif [ "$1" = "-k" ] ; then
		ZAP=
	elif [ "$1" = "-c" ]; then
		CLEAN=1
	fi
	shift
done

# Report errors on missing arguments
if [ "$txt_domain" = "" ] ; then
	Usage "Missing -d domain option"
fi
if [ "$txt_name" = "" ] ; then
	Usage "Missing -n name option"
fi
if [ "$txt_value" = "" ] ; then
	Usage "Missing -v value option"
fi

# Simple check to ensure we are running as root - since we setup certs as root and need to secure password in Zoneedit config file
if [ ! -w /etc/passwd ] ; then
	echo "ERROR: Must run as root"
	exit
fi

# Create dummy config file if there is none yet
if [ ! -f $CONFIG ] ; then
	echo "# Zoneedit config" > $CONFIG
	echo "ZONEEDIT_USER=username" >> $CONFIG
	echo "ZONEEDIT_PASS=password" >> $CONFIG
	chmod 600 $CONFIG
fi

# Source the config file
. $CONFIG

# Check if the config contains dummy values and abort if so
if [ "$ZONEEDIT_USER" = "" -a "$ZONEEDIT_PASS" = "" -o "$ZONEEDIT_USER" = "username" -o "$ZONEEDIT_PASS" = "password" ] ; then
	echo "ERROR: Please edit $CONFIG"
	exit 1
fi

# If we want new session, we clear all work files in temp dir
if [ $ZAP ] ; then
	rm -fr $TMPDIR
fi

# Create tmp dir if it doesn't exist yet
if [ ! -d $TMPDIR ] ; then
	mkdir -p $TMPDIR
fi

# Check if the quiet mode switch was enabled (should not be used with -D or -V)
if [ "$ENABLE_OUTPUT" = "" ] ; then
	if [ $DEBUG ] ; then
		echo "WARNING: Disabling debug mode with -Q option"
	elif [ $VERBOSE] ; then
		echo "WARNING: Disabling verbose mode with -Q option"
	fi
	VERBOSE=
	DEBUG=
fi

# ------------------------------------------------------------------------------
# All initialization is done
# ------------------------------------------------------------------------------

# Start the process
# 2024-05-21 https://github.com/blueslow/sslcertzoneedit
# https://dynamic.zoneedit.com/txt-create.php?host=_acme-challenge.example.com&rdata=depE1VF_xshMm1IVY1Y56Kk9Zb_7jA2VFkP65WuNgu8W
# OR 
# https://dynamic.zoneedit.com/txt-delete.php?host=_acme-challenge.example.com&rdata=depE1VF_xshMm1IVY1Y56Kk9Zb_7jA2VFkP65WuNgu8W

if [ $CLEAN -ne 1 ] ; then
	output Create TXT record using API
	CURL "https://dynamic.zoneedit.com/txt-create.php?host=$txt_name.$txt_domain&rdata=$txt_value" 01update

	# Get the response SUCCESS CODE="200"
	response=`grep 'SUCCESS CODE="200"' $TMPDIR/01update.html `
	if [ $DEBUG ] ; then
		echo "response = '$response'"
	fi

	if [ '$response' == '' ] ; then
		echo "ERROR: Did not get a success response!"
		exit 1
	fi

	echo "OK: Successfully set TXT record $txt_name.$txt_domain=$txt_value"
else
	output Delete TXT record using API
	CURL "https://dynamic.zoneedit.com/txt-delete.php?host=$txt_name.$txt_domain&rdata=$txt_value" 01update

	# Get the response SUCCESS CODE="200"
	response=`grep 'SUCCESS CODE="200"' $TMPDIR/01update.html `
	if [ $DEBUG ] ; then
		echo "response = '$response'"
	fi

	if [ '$response' == '' ] ; then
		echo "ERROR: Did not get a success response!"
		exit 1
	fi

	echo "OK: Successfully deleted TXT record $txt_name.$txt_domain=$txt_value"
fi

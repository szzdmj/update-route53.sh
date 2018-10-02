#!/bin/bash
set -e

# get to the DIR with the Pipfile
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

usage=$(cat <<"EOF"
Usage:
    ./update-route53.sh [--help] --record=<record_set_name>
                        [--ttl=<ttl_seconds>] [--type=<record_type>]
                        --zone=<zone_id>

Update an AWS Route 53 record with your external IP address.

OPTIONS
    --help
        Show this output

    --record=<record_set_name>
        The name of the record set to update (e.g., hello.example.com).

    --ttl=<ttl_seconds>
        The TTL (in seconds) to set on the DNS record. Defaults to 300.

    --type=<record_type>
        The type of the record set to be updated (e.g., A, AAAA). Defaults to A.

    --zone=<zone_id>
        The zone id of the domain to be updated (e.g., ABCD12EFGH3IJ).

    --profile=<profile_name>
        The name of the `awscli` profile to use, if any (e.g., testing).
        (See: https://github.com/aws/aws-cli#getting-started)
	e.x.: aws configure --profile <profile_name>

    --local=<if>
        Use the first local ip address from the if interface.
	For IPv6, use the SLAAC address.
EOF
)

SHOW_HELP=0
ZONEID=""
RECORDSET=""
PROFILE=""
PROFILEFLAG=""
LOCAL=""
TYPE="A"
TTL=300
COMMENT="Auto updating @ `date`"

while [ $# -gt 0 ]; do
    case "$1" in
        --help)
            SHOW_HELP=1
            ;;
        --record=*)
            RECORDSET="${1#*=}"
            ;;
        --ttl=*)
            TTL="${1#*=}"
            ;;
        --type=*)
            TYPE="${1#*=}"
            ;;
        --zone=*)
            ZONEID="${1#*=}"
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            ;;
        --local=*)
            LOCAL="${1#*=}"
            ;;	
        *)
            SHOW_HELP=1
    esac
    shift
done

if [  -z "$RECORDSET" -o -z "$ZONEID" ]; then
    SHOW_HELP=1
fi

if [ $SHOW_HELP -eq 1 ]; then
    echo "$usage"
    exit 0
fi

if [ -n "$PROFILE" ]; then
    PROFILEFLAG="--profile $PROFILE"
fi

if [ "$TYPE" == "A" ]; then
    if [ -n "$LOCAL" ]; then
	# this is probably not portable
	IP=$(ifconfig eth1 | awk '$1=="inet"{print $2}' | head -n1)
    else
	# Get the external IP address from OpenDNS
	# (more reliable than other providers)	
	IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    fi
else
    # AAAA - ipv6
    if [ -n "$LOCAL" ]; then
	# this is probably not portable
	IP=$(ifconfig eth1 | \
		    awk '$1=="inet6"{print $2}' | \
		    awk -F: '$1~/[fF][eE]80/{print $0}' | \
		    head -n1)
    else
	# Get the IPv6 address from OpenDNS
	IP=$(dig +short -6 myip.opendns.com aaaa @resolver1.ipv6-sandbox.opendns.com)
    fi
fi

# Get the current ip address on AWS
# Requires jq to parse JSON output
AWSIP="$(
   pipenv run aws $PROFILEFLAG route53 list-resource-record-sets \
      --hosted-zone-id "$ZONEID" --start-record-name "$RECORDSET" \
      --start-record-type "$TYPE" --max-items 1 \
      --output json | jq -r \ '.ResourceRecordSets[].ResourceRecords[].Value'
)"


# Get current dir
# (from http://stackoverflow.com/a/246128/920350)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGFILE="$DIR/update-route53.log"

# Requires sipcalc to check ip is valid
if sipcalc "$IP" | grep -q ERR; then
    echo "Invalid IP address: $IP" >> "$LOGFILE"
    exit 1
fi

#compare local IP to dns of recordset
if [ "$IP" ==  "$AWSIP" ]; then
    # code if found
    # echo "IP is still $IP. Exiting" >> "$LOGFILE"
    exit 0
else
    echo "IP has changed to $IP" >> "$LOGFILE"
    # Fill a temp file with valid JSON
    TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
    trap "rm $TMPFILE;" exit
    cat > ${TMPFILE} << EOF
    {
      "Comment":"$COMMENT",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$RECORDSET",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

    # Update the Hosted Zone record
    pipenv run aws $PROFILEFLAG route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://"$TMPFILE" \
        --query '[ChangeInfo.Comment, ChangeInfo.Id, ChangeInfo.Status, ChangeInfo.SubmittedAt]' \
        --output text >> "$LOGFILE"
    echo "" >> "$LOGFILE"
fi


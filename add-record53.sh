#!/bin/bash
set -e

# get to the DIR with the Pipfile
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR


usage=$(cat <<"EOF"
Usage:
    ./add-record53.sh [--help] --record=<record_set_name>
                      [--ttl=<ttl_seconds>] [--type=<record_type>]
                      --zone=<zone_id>

Add an AWS Route 53 record

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

    --value=<str>
        The value to store in the record (e.g., 1.2.3.4)
EOF
)

SHOW_HELP=0
TTL=86400
TYPE="CNAME"
VALUE=""
RECORDSET=""
ZONEID=""
PROFILE=""

COMMENT="Adding domain $name @ $(date)"

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
        --value=*)
            VALUE="${1#*=}"
            ;;	
        *)
            SHOW_HELP=1
    esac
    shift
done

if [  -z "$RECORDSET" -o -z "$ZONEID" ]; then
    SHOW_HELP=1
fi

if [ "$SHOW_HELP" -eq 1 ]; then
    echo "$usage"
    exit 0
fi

# Fill a temp file with valid JSON
TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
trap "rm $TMPFILE;" exit
cat > ${TMPFILE} <<EOF
{
    "Comment": "$COMMENT",
    "Changes": [
	{
	    "Action": "UPSERT",
 	    "ResourceRecordSet": {
		"Name": "$RECORDSET",
		"Type": "$TYPE",
		"TTL": $TTL,
		"ResourceRecords": [
		    {
			"Value": "$VALUE"
		    }
		]
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
       --output text
echo ""

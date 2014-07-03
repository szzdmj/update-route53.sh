#!/bin/bash

# Hosted Zone ID e.g. BJBK35SKMM9OE
ZONEID="enter zone id here"

# The CNAME you want to update e.g. hello.example.com
RECORDSET="enter cname here"

# More advanced options below
# The Time-To-Live of this recordset
TTL=300
# Change this if you want
COMMENT="Auto updating @ `date`"
# Change to AAAA if using an IPv6 address
TYPE="A"

# Get the external IP address
IP=`curl -ss https://icanhazip.com/`

# Get current dir (stolen from http://stackoverflow.com/a/246128/920350)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGFILE="$DIR/update-route53.log"
IPFILE="$DIR/update-route53.ip"

echo "Updating IP to $IP..." >> "$LOGFILE"

# Check if the IP has changed
if [ ! -f "$IPFILE" ]
    then
    touch "$IPFILE"
fi

if grep -Fxq "$IP" "$IPFILE"; then
    # code if found
    echo "IP has NOT changed" >> "$LOGFILE"
else
    echo "IP has changed" >> "$LOGFILE"
    # Fill a temp file with valid JSON
	TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
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
	aws route53 change-resource-record-sets \
	--hosted-zone-id $ZONEID \
	--change-batch file://"$TMPFILE" >> "$LOGFILE"
	echo "" >> "$LOGFILE"

	# Clean up
	rm $TMPFILE
fi

# All Done - cache the IP address for next time
echo "$IP" > "$IPFILE"

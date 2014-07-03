#!/bin/bash

# Hosted Zone ID e.g. JBJ3HB5453NH34J
ZONEID="enter zone id here"

# The CNAME you want to update e.g. hello.example.com
RECORDSET="enter cname here"

# Below are some more advanced options

# The Time-To-Live of this recordset
TTL=300
# Change this if you want
COMMENT="Auto updating @ `date`"
# Change to AAAA if using an IPv6 address
TYPE="A"

# Get the external IP address
IP=`curl -ss https://icanhazip.com/`

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
echo "Updating IP to $IP..." >> update-route53.log
aws route53 change-resource-record-sets \
--hosted-zone-id $ZONEID \
--change-batch file://"$TMPFILE" >> update-route53.log
echo "" >> update-route53.log

# Clean up
rm $TMPFILE

# All Done
update-route53.sh
===

## Purpose

To provide dyndns updates to a route53 record programatically 

## Setup

Install the dependencies:
  * sipcalc
  * dig
  * jq
  * awscli

On debian:

    sudo apt-get install sipcalc jq awscli dnsutils
    
Configure aws:

    aws configure
    
or:

    aws configure --profile mydnsprofile

configure a cron job or systemd timer to execute update-route53.sh on a regular interval with the params you desire.

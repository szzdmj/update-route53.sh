update-route53.sh
===

## Purpose

To provide dyndns updates to a route53 record programatically 

## Setup

Install the dependencies:
  * sipcalc
  * dig
  * jq
  * pipenv

On debian:

```shell
sudo apt-get install sipcalc jq dnsutils
python3 -m pip install pipenv --user
pipenv sync
```    


Configure aws:

```shell
pipenv run aws configure
```

or:

```shell
    pipenv run aws configure --profile mydnsprofile
```

configure a cron job or systemd timer to execute update-route53.sh on a regular interval with the params you desire.

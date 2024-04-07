update-route53.sh
===

## Purpose

To provide dyndns updates to a route53 record programatically 

## Setup

Install the dependencies:
  * sipcalc
  * dig
  * jq
  * ifconfig
  * pipenv

On debian:

install required system packages:

```shell
sudo apt-get install sipcalc jq dnsutils net-tools
```

install required python packages using pipenv:

```shell
python3 -m pip install pipenv --user
pipenv sync
```    

or install required python packages using venv:

```shell
python3 -m venv ./.venv/
. ./.venv/bin/activate
pip install -r ./requirements.txt 
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

#!/bin/bash
## Usage: generate-letsencrypt-certificate.sh domain
## AUTHOR: Panda zhaolin@rokid.com
function check_http_server(){
        read -p "please input web service ROOT path:" WEB_SERVER_PATH
        test_uuid=`date|md5sum|cut -d"-" -f1`
        touch $WEB_SERVER_PATH/$test_uuid
        http_code=`curl -I http://localhost/$test_uuid 2>/dev/null | head -n 1 |cut -d" " -f 2`
        rm -rf $WEB_SERVER_PATH/$test_uuid
        [ "$http_code" != "200" ] && echo -e "\033[31m web service ROOT path:$WEB_SERVER_PATH is incorrect,try again:\033[0m" && check_http_server
}

cd `dirname $0`
DOMAIN=$1
ping $DOMAIN -c 1 2>&1 | grep unknown > /dev/null && echo "can not resolve ip by domain : $DOMAIN "&& exit 1
WEB_SERVER_PATH="."
[ -z "$DOMAIN" ] && echo "usage: generate-letsencrypt-certificate.sh example.rokid.com" && exit 1
[ ! -f account.key ] && echo "create account.key" && openssl genrsa 4096 > account.key

echo "create $DOMAIN.key:"
openssl genrsa 4096 > $DOMAIN.key
openssl req -new -sha256 -key $DOMAIN.key -subj "/CN=$DOMAIN" > $DOMAIN.csr
[ ! -f acme_tiny.py ] && wget https://raw.githubusercontent.com/diafygi/acme-tiny/master/acme_tiny.py
netstat -nlt|grep "80" -w >& /dev/null
is_listen_80=$?
if [ $is_listen_80 -ne 0 ]
then
        nohup python -m SimpleHTTPServer 80 >& /tmp/python.log &
else
        check_http_server
fi
mkdir -p $WEB_SERVER_PATH/.well-known/acme-challenge
python acme_tiny.py --account-key ./account.key --csr ./$DOMAIN.csr --acme-dir .well-known/acme-challenge > ./$DOMAIN.crt
if [ $? -eq 0 ]
then
        [ ! -f intermediate.pem ] && wget https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem -O intermediate.pem 2>/dev/null
        cat $DOMAIN.crt intermediate.pem > $DOMAIN.pem
        echo "create certificate success"
fi
rm -rf $WEB_SERVER_PATH/.well-known
[  $is_listen_80 -eq 1 ] && netstat -nltp|grep "80" -w |tr -s " "|cut -d" " -f 7| cut -d"/" -f 1 |xargs -I {} kill {}

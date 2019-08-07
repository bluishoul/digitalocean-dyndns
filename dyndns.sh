#!/bin/sh

api_host="https://api.digitalocean.com/v2"
sleep_interval=${SLEEP_INTERVAL:-300}

die() {
    echo "$1"
    exit 1
}

test -z $DIGITALOCEAN_TOKEN && die "DIGITALOCEAN_TOKEN not set!"
test -z $DOMAIN && die "DOMAIN not set!"
test -z $NAME && die "NAME not set!"

dns_list="$api_host/domains/$DOMAIN/records"

while ( true ); do
    for subdomain in $(echo $NAME | sed "s/,/ /g")
    do
        echo "Checking domain: $subdomain.$DOMAIN ..."
        domain_records=$(curl -s -X GET \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
            "$dns_list?per_page=200")

        record_id=$(echo $domain_records| jq ".domain_records[] | select(.type == \"A\" and .name == \"$subdomain\") | .id")
        record_data=$(echo $domain_records| jq -r ".domain_records[] | select(.type == \"A\" and .name == \"$subdomain\") | .data")
        
        test -z $record_id && die "No record found with given domain name!"

        ip="$(curl -s myip.ipip.net | grep -E -o '([0-9]{1,3}[\.]){3}[0-9]{1,3}')"
        data="{\"type\": \"A\", \"name\": \"$subdomain\", \"data\": \"$ip\"}"
        url="$dns_list/$record_id"

        if [[ -n $ip ]]; then
            if [[ "$ip" != "$record_data" ]]; then
                echo "existing DNS record address ($record_data) doesn't match current IP ($ip), sending data=$data to url=$url"

                curl -s -X PUT \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
                    -d "$data" \
                    "$url" &> /dev/null
            fi
        else
            echo "IP wasn't retrieved within allowed interval. Will try $sleep_interval seconds later.."
        fi
    done

    sleep $sleep_interval
done

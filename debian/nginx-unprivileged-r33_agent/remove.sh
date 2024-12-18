echo "Authorization: APIToken ${XC_API_KEY}"
echo "https://${XC_TENANT}.console.ves.volterra.io/api/nginx/one/namespaces/default/instances?filter_fields=hostname&filter_ops=IN&filter_values='$(hostname)'"

curl --connect-timeout 30 --retry 10 --retry-delay 5 --silent --header 'Content-Type: application/json' \
--header "Authorization: APIToken ${XC_API_KEY}" \
--location "https://${XC_TENANT}.console.ves.volterra.io/api/nginx/one/namespaces/default/instances?filter_fields=hostname&filter_ops=IN&filter_values='$(hostname)'" \
--output instances.json

instance_id=$(jq '.items[] | select(.hostname == "'$(hostname)'") | .object_id' instances.json)
echo "instance_id ${instance_id}"

instance_id=$(echo "${instance_id}" | tr -d '"')
echo "instance_id ${instance_id}"

curl --connect-timeout 30 --retry 10 --retry-delay 5 --silent --header 'Content-Type: application/json' \
--header "Authorization: APIToken ${XC_API_KEY}" \
--location "https://${XC_TENANT}.console.ves.volterra.io/api/nginx/one/namespaces/default/instances/${instance_id}" \
--request DELETE

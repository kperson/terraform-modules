#!/bin/bash

set -x

text=$(cat $1)
needle='MY_PASSWORD_TEMPLATE'
password=$(openssl rand -hex 12)

new_json=${text/$needle/$password}

aws secretsmanager create-secret --name $2 --kms-key-id $3 --secret-string "$new_json"
aws rds modify-db-cluster --db-cluster-identifier $4 --master-user-password $password --apply-immediately
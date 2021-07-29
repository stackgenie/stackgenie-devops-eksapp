#!/bin/bash
set -e

## Workspace ENV validation
[[ -z ${WORKSPACE_ENV} ]] && { echo "Exit error: WORKSPACE_ENV is null"; exit 1; }
echo "nameserver 8.8.8.8" >>/etc/resolv.conf

## Configuring AWS Credentials of Organization acoount
## to access child accounts(assume role) 
mkdir -p ~/.aws && echo -e "[org] \naws_access_key_id = ${AWS_ACCESS_KEY_ID}\naws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" > ~/.aws/credentials

## Function to assume child accounts role for terraform execution, 
## export the credentials as environment variables 
assumeRole () {
  ASSUME_ROLE_CREDS=$(aws sts assume-role --role-arn ${ROLE_ARN} --role-session-name devops-bot --profile org)
  export "AWS_ACCESS_KEY_ID=$(echo ${ASSUME_ROLE_CREDS} | jq -r '.Credentials.AccessKeyId')"
  export "AWS_SECRET_ACCESS_KEY=$(echo ${ASSUME_ROLE_CREDS} | jq -r '.Credentials.SecretAccessKey')"
  export "AWS_SESSION_TOKEN=$(echo ${ASSUME_ROLE_CREDS} | jq -r '.Credentials.SessionToken')"
}


## Terraform execution function, will do apply and destroy
## depending on the variable input 'TF_VERBOSE'
terrformExecution () {
  terraform init
  if [[ ${TF_VERBOSE} == 'apply' ]]; then
    ENV=${WORKSPACE_ENV} make plan >/dev/null && ENV=${WORKSPACE_ENV} make ${TF_VERBOSE}
  elif [[ ${TF_VERBOSE} == 'destroy' ]] ; then
    ENV=${WORKSPACE_ENV} make ${TF_VERBOSE}
  fi
  rm -rf .terraform*
}


## Switch according with accounts provided (Main script block)
case ${WORKSPACE_ENV} in
  dev|mgmt|prod)
    ROLE_ARN=$(echo ${ASSUME_ROLES} | jq -r ".AssumeRoles[] | select(.name==\"${WORKSPACE_ENV}\") | .role")
    assumeRole
    terrformExecution
    ;;
  *)
    echo "Exiting..."
    exit 1 
    ;;
esac

### END OF SCRIPT ###

#!/bin/bash
set -e

## Workspace ENV validation and export GitHub token
[[ -z ${WORKSPACE_ENV} ]] && { echo "Exit error: WORKSPACE_ENV is null"; exit 1; }
echo "nameserver 8.8.8.8" >>/etc/resolv.conf

## Variable declaration
TF_STATE_BUCKET="<replace-with-the-remote-tfstate-bucket>"
VALUES_BUCKET="<replace-with-the-values-bucket>"
ARGO_USER="admin"

## Configuring AWS Credentials of Organization acoount
## to access child accounts(assume role) 
mkdir -p ~/.aws && echo -e "[org] \naws_access_key_id = ${AWS_ACCESS_KEY_ID}\naws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" > ~/.aws/credentials

## Function to assume child accounts role for Flux bootstrap, 
## export the credentials as environment variables 
assumeRole () {
  ASSUME_ROLE_CREDS=$(aws sts assume-role --role-arn ${ROLE_ARN} --role-session-name devops-bot --profile org)
  export "AWS_ACCESS_KEY_ID=$(echo ${ASSUME_ROLE_CREDS} | jq -r '.Credentials.AccessKeyId')"
  export "AWS_SECRET_ACCESS_KEY=$(echo ${ASSUME_ROLE_CREDS} | jq -r '.Credentials.SecretAccessKey')"
  export "AWS_SESSION_TOKEN=$(echo ${ASSUME_ROLE_CREDS} | jq -r '.Credentials.SessionToken')"
}

## Downlaod terraform state file from S3 and fetch the EKS cluster name and more
getConfig () {
  assumeRole
  aws s3 cp s3://${TF_STATE_BUCKET}/env:/${WORKSPACE_ENV}/eu-west-2/tfstate.json /tmp/ >/dev/null
  export CLUSTER_NAME=$(jq -r '.resources[] | select(.type=="aws_eks_cluster") | .instances[] | .attributes.name' /tmp/tfstate.json)
  aws eks update-kubeconfig --name ${CLUSTER_NAME} >/dev/null
  if ! kubectl get namespace web-app 2>/dev/null; then kubectl create namespace web-app; fi
  export ARGO_GET_SSM_SECRET=$(aws ssm get-parameter --name ARGO_LOGIN_SECRET --query Parameter.Value --output text | openssl aes-256-cbc -d -a -iter 2 -k ${CLUSTER_NAME})
}

## Function to reset Initial Password and deploy prerequisites for getting UI
webappInstall () {
  timeout 1200 sh -c "echo -n Verify ArogCD Connectivity! Please wait.; until curl -sfkI https://${ARGO_HOSTNAME} &>/dev/null; do echo -n .; sleep 1; done;echo Done!;"
  argocd login ${ARGO_HOSTNAME} --grpc-web --insecure --username ${ARGO_USER} --password ${ARGO_GET_SSM_SECRET} >/dev/null
  
argocd repo add https://github.com/stackgenie/stackgenie-devops-apptest.git --username ${USER_GITHUB} --password ${API_TOKEN_GITHUB} --name sample   #follow step 10 and replace the repo name here

argocd app create sample \
  --repo https://github.com/stackgenie/stackgenie-devops-apptest.git \  #follow step 10 and replace the repo name here
  --revision dev \                                                      #Replace with the branch name
  --path . \
  --dest-namespace web-app \
  --dest-server https://kubernetes.default.svc
}

## ISTIO bootstrap function
webappBootstrap () {
  if [[ ${WEBAPP_VERBOSE} == 'install' ]]; then
    webappInstall
  elif [[ ${WEBAPP_VERBOSE} == 'uninstall' ]]; then
    argocd login ${ARGO_HOSTNAME} --grpc-web --insecure --username ${ARGO_USER} --password ${ARGO_GET_SSM_SECRET} >/dev/null
    argocd app delete sample --cascade
  else 
    echo "${WEBAPP_VERBOSE} value not allowed"
  fi
}

## Switch according with accounts provided (Main script block)
case ${WORKSPACE_ENV} in
  dev|mgmt|prod)
    ROLE_ARN=$(echo ${ASSUME_ROLES} | jq -r ".AssumeRoles[] | select(.name==\"${WORKSPACE_ENV}\") | .role")
    getConfig
    webappBootstrap
    ;;
  *)
    echo "Exiting..."
    exit 1 
    ;;
esac


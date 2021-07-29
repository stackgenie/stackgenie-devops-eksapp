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
  aws s3 cp s3://${VALUES_BUCKET}/argocd /tmp/values --recursive >/dev/null
  aws s3 cp s3://${TF_STATE_BUCKET}/env:/${WORKSPACE_ENV}/eu-west-2/tfstate.json /tmp/ >/dev/null
  export CLUSTER_NAME=$(jq -r '.resources[] | select(.type=="aws_eks_cluster") | .instances[] | .attributes.name' /tmp/tfstate.json)
  aws eks update-kubeconfig --name ${CLUSTER_NAME} >/dev/null
  if ! kubectl get namespace argocd 2>/dev/null; then kubectl create namespace argocd; fi
  if ! kubectl get namespace ingress-nginx 2>/dev/null; then kubectl create namespace ingress-nginx; fi
  if ! kubectl get namespace external-dns 2>/dev/null; then kubectl create namespace external-dns; fi
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  DNS_ROLE_ARN=$(jq -r '.resources[] | select(.module=="module.iam_assumable_role_with_oidc") | select(.type=="aws_iam_role") | .instances[] | .attributes.arn' /tmp/tfstate.json) && DNS_ROLE_ARN=${DNS_ROLE_ARN//\//\\/}
  sed -i "s/DNS_ARN/${DNS_ROLE_ARN}/g" /tmp/values/externalDNS-values.yaml
  sed -i "s/HOSTNAME/${ARGO_HOSTNAME}/g" /tmp/values/argo-values.yaml
  sed -i "s/DOMAIN_NAME/${DOMAIN_NAME}/g" /tmp/values/externalDNS-values.yaml
}

## Function to reset Initial Password and deploy prerequisites for getting UI
postInstall () {
  timeout 120 sh -c "echo -n Verify Initial Secret! Please wait.; until kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null ; do echo -n .; sleep 1; done;echo Done!!;"
  ARGO_INITIAL_SECRET=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) 
  ARGO_SECRET=$(openssl rand -base64 12)
  kubectl port-forward service/argocd-server -n argocd 8080:443 &>/dev/null & 
  
  sleep 30; argocd login localhost:8080 --grpc-web --insecure --username ${ARGO_USER} --password ${ARGO_INITIAL_SECRET} >/dev/null

  argocd repo add https://charts.bitnami.com/bitnami --type helm --name bitnami
  argocd repo add https://kubernetes.github.io/ingress-nginx --type helm --name ingress-nginx
  argocd app create ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --helm-chart ingress-nginx \
    --revision 3.34.0 \
    --dest-namespace ingress-nginx \
    --self-heal \
    --sync-policy auto \
    --sync-option Prune=true \
    --sync-option CreateNamespace=true \
    --sync-option ApplyOutOfSyncOnly=true \
    --dest-server https://kubernetes.default.svc
  argocd app create external-dns \
    --repo https://charts.bitnami.com/bitnami \
    --helm-chart external-dns \
    --revision 5.1.1 \
    --dest-namespace external-dns \
    --values-literal-file /tmp/values/externalDNS-values.yaml \
    --self-heal \
    --sync-policy auto \
    --sync-option Prune=true \
    --sync-option CreateNamespace=true \
    --sync-option ApplyOutOfSyncOnly=true \
    --dest-server https://kubernetes.default.svc

  argocd account update-password  --current-password ${ARGO_INITIAL_SECRET} --new-password ${ARGO_SECRET}
  ARGO_SECRET=$(echo ${ARGO_SECRET} | openssl aes-256-cbc -e -a -iter 2 -k ${CLUSTER_NAME})
  aws ssm put-parameter --name "ARGO_LOGIN_SECRET" --type "String" --value ${ARGO_SECRET} --overwrite --description "ArgoCD login password stored in encrypted format: Refer wiki for decryption" >/dev/null
  kubectl delete -n argocd secrets argocd-initial-admin-secret >/dev/null
}

## EKS bootstrap function
argoBootstrap () {
  if [[ ${ARGO_VERBOSE} == 'install' ]]; then
    helm install --create-namespace -n argocd argocd argo/argo-cd -f /tmp/values/argo-values.yaml
    sleep 30; postInstall
  elif [[ ${ARGO_VERBOSE} == 'uninstall' ]]; then
    kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &
    ARGO_SECRET=$(aws ssm get-parameter --name ARGO_LOGIN_SECRET --query Parameter.Value --output text | openssl aes-256-cbc -d -a -iter 2 -k ${CLUSTER_NAME})
    sleep 10; argocd login localhost:8080 --grpc-web --insecure --username ${ARGO_USER} --password ${ARGO_SECRET} >/dev/null
    sleep 10; argocd app delete ingress-nginx --cascade && argocd app delete external-dns --cascade
    sleep 5; helm uninstall -n argocd argocd
    sleep 3; kubectl delete namespace ingress-nginx && kubectl delete namespace external-dns
  else 
    echo "${ARGO_VERBOSE} value not allowed"
  fi
}

## Switch according with accounts provided (Main script block)
case ${WORKSPACE_ENV} in
  dev|mgmt|prod)
    ROLE_ARN=$(echo ${ASSUME_ROLES} | jq -r ".AssumeRoles[] | select(.name==\"${WORKSPACE_ENV}\") | .role")
    getConfig
    argoBootstrap
    ;;
  *)
    echo "Exiting..."
    exit 1 
    ;;
esac


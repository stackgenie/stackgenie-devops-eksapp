# Multi-environment application deployment on EKS using terraform

  

This blog is to help to demonstrate the procedure to automate the application deployment using DevOps tools like Terraform, AWS EKS (Elastic Kubernetes Services), GitHub Actions and Argo-CD. The process includes but is not limited to implementation and the configuration of various tools. The outcome of this process is to automate the deployment process using CI/CD (Continuous Integration and Continuous Deployment).

  

# Components:


- AWS EKS (Elastic Kubernetes Service)

- Terraform

- GitHub

- GitHub Actions

- Argo-CD

- Microsoft Visual Studio Code IDE (Local)

## Prerequisites

-   [Installing](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)  and  [configuring](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)  AWS CLI
-   [Terraform](https://www.terraform.io/downloads.html)
-   [Kubectl](https://kubernetes.io/docs/tasks/tools/)
-   [ArgoCD](https://argoproj.github.io/argo-cd/cli_installation/#linux-and-wsl)
-   Create a public hosted zone in Route 53.  [See tutorial](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html)
-   Request a public certificate with AWS Certificate Manager.  [See tutorial](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html)

## Deployments

#### To deploy the web application cluster, we create in AWS and GitHub:

- AWS Organization (dev, staging/qa and prod)
- Need to create an s3 bucket to store the terraform state file.

  - The bucket should have versioning enabled and default encryption enabled.
-   A DynamoDB table to store terraform state-lock file.
- Create an s3 bucket to store Helm values file. *refer step7*
- IAM Roles in all accounts (dev, staging and prod).
  
  - IAM user in the main account have the privilege's to access this role. 
- An IAM user in main account

  - IAM user should have programmatic access.
  - Have the authority to access  (sts assume role) roles in the follower accounts.
  - Should have the permission to access s3 for tf-state upload and DynamoDB table to upload tf-state lock file.
-  A GitHub API token for GitHub Actions.

#### Using terraform we will deploy:

- A single node infrastructure (For high availability you can change the node count and add multi-AZ's)

- A virtual private cloud (VPC) configured with public and private subnets according to AWS best practices.

- In the public subnets:

	- Managed network address translation (NAT) gateways to allow outbound internet access for resources in the private subnets.

- In the private subnets:

	- A group of Kubernetes nodes.
	- An Amazon EKS cluster, which provides the Kubernetes control plane.
	- An EFS storage.

#### In ArgoCD:

- A Nginx Ingress Controller.
- An External DNS for EKS.
- A sample web application.

## GitHub Action

[GitHub Actions](https://github.com/features/actions) makes it easy to automate all your software workflows, now with world-class CI/CD. Build, test, and deploy your code right from GitHub. Make code reviews, branch management, and issue triaging work the way you want.

Here, GitHub actions for the Continuous Integration and branch management. Prerequisites for GitHub Actions Integration:
- Add AWS credentials as Git Secrets. [See tutorial](https://docs.github.com/en/actions/reference/encrypted-secrets)

## Argo CD
[Argo CD](https://argoproj.github.io/argo-cd/) is a declarative, [GitOps](https://www.weave.works/blog/what-is-gitops-really) continuous delivery tool for Kubernetes.

#### Why Argo CD?

1.  Application definitions, configurations, and environments should be declarative and version controlled.
2.  Application deployment and lifecycle management should be automated, auditable, and easy to understand.

Here, Argo CD used to deploy the infrastructure and applications on the Kubernetes.

## Architecture

Architecture of web application:

![Alt text](images/Final-Architecture.jpg?raw=true  "k8s Architecture")

## How to work
1. Create a repo on your GitHub account and complete following steps
 
    - Create a GitHub personal access token [See tutorial](https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token)
    - Add GitHub secrets on the repo [See tutorial](https://docs.github.com/en/actions/reference/encrypted-secrets)
	   > **Note:** The  ***repository secret variable***(Name) that you have given here also need to be ***replaced*** in the GitHub action manifest too. 

    - GitHub Secrets Example

     ```
     USER_GITHUB            --> (Optional) github user variable for accessing private repositories.
     API_TOKEN_GITHUB       --> (Optional) github token variable for accessing private repositories.
     AWS_ACCESS_KEY_ID      --> AWS Access Key for getting access to the AWS account and services.
     AWS_SECRET_ACCESS_KEY  --> AWS Secret Access Key for getting access to the AWS account and services.
     ASSUME_ROLES           --> AWS role to assume access towards other organization accounts.
     ```
    - The ASSUME_ROLES should be in below format.
     ```
     {"AssumeRoles":[{"name":"dev","role":"arn:aws:iam::11111111111:role/account1-rolename"},{"name":"mgmt","role":"arn:aws:iam::2222222222:role/account2-rolename"},{"name":"prod","role":"arn:aws:iam::3333333333:role/account3-rolename"}]} 
     ```
2. Clone this GitHub repositories 
```
git clone https://github.com/stackgenie/stackgenie-devops-eksapp.git
```
3. Replace the **main.tf** file with the AWS s3 bucket name that you have created for storing terraform state file and DynamoDB table name.
```
terraform {
backend "s3" {
bucket = "terraform-tfstate-bucket-name"
region = "eu-west-2"
dynamodb_table = "yourtablename-terraform-state-locking"
```
4. Make changes accordingly on the **variable.tf** file.
5. In eks.tf we are using SPOT instance for the cost optimization. When it comes to production you have to choose on-demand instances. [For reference](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
6. Make changes on main.yml (.github/workflows/main.yml) *follow step-7*
> Deploymet has been done through different stages. 
> 1. Terraform deployment
> 2. Argo CD deployment along with External-DNS and Nginx ingress controller
> 3. Sample Web Application deployment
7. Upload the values.yaml files in the s3 bucket.

- argo-cd values file
```
server:
  
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    hosts: 
      - HOSTNAME
```

- external-DNS values file
```
domainFilters:
  - DOMAIN_NAME
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: DNS_ARN
```
> You can find these values files inside the cloned repo.
8. For terraform deployment you have to make changes on ***Terraform Variables***.
> Two values allowed, Terraform **"apply"** and **"destroy"**
```
TF_VERBOSE: 'apply/destroy'
```
9. For Argo CD deployment make below changes.
> Two values allowed, Argo **"install"** and **"uninstall"**
> Route53 domain for hosted zone eg: env.yourdomain.com.
> Hostname with domain FQDN eg: argocd.env.yourdomain.com.
```
ARGO_VERBOSE: 'install/uninstall'
DOMAIN_NAME: 'dev.yourdomain.com'
ARGO_HOSTNAME: 'argo.dev.yourdomain.com'
```
10. Sample web application deployment.
> Create a git repo and add below manifest file in it.
```
---
apiVersion: v1
kind: Namespace
metadata:
  name: sample
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
  namespace: sample
spec:
  selector:
    matchLabels:
      app: hello
  replicas: 3
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: "gcr.io/google-samples/hello-app:2.0"
--- 
apiVersion: v1
kind: Service
metadata:
  name: hello-service
  namespace: sample
  labels:
    app: hello
spec:
  type: ClusterIP
  selector:
    app: hello
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
--- 
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-ingress
  namespace: sample
spec:
  rules:
  - host: sample.yourdomain.com
    http:
      paths:
      - backend:
          serviceName: hello-service
          servicePort: 80
```
- Update the following lines in the web app action file
```
argocd repo add https://github.com/<your-repo-name>.git --name sample
argocd app create sample \
	--repo https://github.com/<your-repo-name>.git \
	--revision <branch-name> \
	--path . \
	--dest-namespace web-app \
	--dest-server https://kubernetes.default.svc
}
```
> **NOTE:** If you are using a private repo then use 
> --username your-github-username --password your-github-password/token 
> with ***argocd repo add*** command.

11. Main changes that need to done before end to end deployment.

- Give the reference branch, when a push is triggered on this branch it will trigger the deployment accordingly. 
```
on:

push:

branches:
- <your-branch-name>
pull_request:
branches:
- <your-branch-name>
```

- Specify the environment in which this deployment is going to happen.
```
WORKSPACE_ENV: 'your-env'
```

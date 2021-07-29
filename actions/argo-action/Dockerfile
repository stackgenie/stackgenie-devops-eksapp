FROM alpine:latest

COPY entrypoint.sh /tmp/entrypoint.sh

RUN apk add jq aws-cli bash curl openssl && \
  curl -fsSL "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl && \
  curl -fsSL "https://github.com/mikefarah/yq/releases/download/$(curl -sL https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r .tag_name)/yq_linux_amd64"  -o /usr/local/bin/yq && \
  curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/$(curl -sL https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r .tag_name)/argocd-linux-amd64" -o /usr/local/bin/argocd && \
  curl -fsSL "https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3" | bash && \
  chmod +x /usr/local/bin/kubectl /usr/local/bin/yq /usr/local/bin/argocd /tmp/entrypoint.sh

ENTRYPOINT [ "/tmp/entrypoint.sh" ]



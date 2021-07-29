FROM alpine:latest

COPY entrypoint.sh /tmp/entrypoint.sh

RUN apk add make jq aws-cli wget bash git && \
  wget -q https://releases.hashicorp.com/terraform/1.0.6/terraform_1.0.6_linux_amd64.zip -P /tmp/ && \
  unzip -qq /tmp/terraform_1.0.6_linux_amd64.zip -d /usr/bin && \
  chmod +x /tmp/entrypoint.sh

ENTRYPOINT [ "/tmp/entrypoint.sh" ]

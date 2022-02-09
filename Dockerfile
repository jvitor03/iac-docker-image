FROM golang:1.15-alpine AS ssm-builder

RUN apk update && \
    apk add git gcc build-base bash
RUN git clone https://github.com/aws/session-manager-plugin.git && \
    cd session-manager-plugin && \ 
    make build && \
    cp bin/linux_amd64_plugin/session-manager-plugin /session-manager-plugin

FROM python:3.9.10-alpine

LABEL maintainer="Wildlife Studios"

ARG VAULT_VERSION=1.7.2
ARG KUBECTL_VERSION=v1.21.1

# Base dependencies
RUN apk update && \
    apk add --no-cache \
      curl \
      make \
      gcc \
      build-base \
      curl \
      libffi-dev \
      musl-dev \
      python3-dev \
      openssl-dev \
      cargo \
      rust

# Poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
RUN ln -s /root/.local/share/pypoetry/venv/bin/poetry /usr/local/bin/poetry

# Session-manager-plugin
COPY --from=ssm-builder /session-manager-plugin /usr/local/bin

# Vault
RUN curl https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip --output - | \
      busybox unzip -d /usr/bin/ - && \
      chmod +x /usr/bin/vault

# AWS CLI v1
RUN pip3 install awscli

# AWS CLI v2
RUN curl -L https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip --output - | \
      busybox unzip -d /tmp/ - && \
      chmod +x -R /tmp/aws && \
      ./tmp/aws/install -i /usr/local/aws-cli-v2 -b /usr/local/bin/aws-cli-v2 && \
      rm -rf ./tmp/aws

RUN echo "if [ ! -z \${AWSCLIV2} ]; then rm -f /usr/bin/aws; ln -s /usr/local/bin/aws-cli-v2/aws /usr/bin/aws; fi" >> ~/.shrc
RUN echo "if [ ! -z \${AWSCLIV2} ]; then rm -f /usr/bin/aws; ln -s /usr/local/bin/aws-cli-v2/aws /usr/bin/aws; fi" >> ~/.bashrc
ENV ENV="/root/.shrc"

# Kubectl
ADD https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl /bin/kubectl
RUN chmod u+x /bin/kubectl

ENTRYPOINT [ "/bin/bash", "-c" ]
CMD [ "bash" ]
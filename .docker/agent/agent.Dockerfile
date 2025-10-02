# Copyright (c) CloudBees, Inc.

FROM alpine:3.22.0

# Build argument to determine if we should create a user
ARG CREATE_USER=false
ARG USER=bp-agent

ENV TF_VERSION=1.9.8 \
    TF_LINT_VERSION=v0.59.1 \
    TF_DOCS_VERSION=v0.20.0 \
    KUBECTL_VERSION=1.31.2 \
    VELERO_VERSION=1.16.1 \
    EKSCTL_VERSION=0.210.0 \
    ARCH=amd64 \
    USER=${USER}

RUN apk add --update --no-cache \
    bash \
    unzip \
    curl \
    git \
    make \
    pre-commit \
    perl \
    aws-cli \
    yq \
    jq

RUN curl -sLO https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH}.zip && \
    unzip terraform_${TF_VERSION}_linux_${ARCH}.zip && \
    mv terraform /usr/bin/terraform && \
    chmod +x /usr/bin/terraform && \
    rm terraform_${TF_VERSION}_linux_${ARCH}.zip

RUN curl -L -o /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/download/${TF_LINT_VERSION}/tflint_linux_${ARCH}.zip \
    && unzip /tmp/tflint.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/tflint \
    && rm /tmp/tflint.zip

RUN curl -L https://github.com/terraform-docs/terraform-docs/releases/download/${TF_DOCS_VERSION}/terraform-docs-${TF_DOCS_VERSION}-linux-${ARCH}.tar.gz \
    | tar xz -C /usr/local/bin terraform-docs

RUN curl -sLO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

RUN curl -sLO https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz && \
    tar zxvf velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz && \
    mv velero-v${VELERO_VERSION}-linux-${ARCH}/velero /usr/bin/velero && \
    chmod +x /usr/bin/velero && \
    rm velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz

RUN curl -sLO "https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_Linux_${ARCH}.tar.gz" && \
    tar -xzf eksctl_Linux_${ARCH}.tar.gz -C /usr/bin && \
    chmod +x /usr/bin/eksctl && \
    rm eksctl_Linux_${ARCH}.tar.gz

# Conditionally create user and set up rootless environment.
# Recomendation but not valid for CloudBees.io because it requires root user to operate with the Workspace
RUN if [ "$CREATE_USER" = "true" ]; then \
        adduser -s /bin/bash -h /${USER} -D ${USER} && \
        echo "User ${USER} created"; \
    fi

# Set working directory
RUN if [ "$CREATE_USER" = "true" ]; then \
        mkdir -p /${USER}; \
    fi

WORKDIR ${CREATE_USER:+/${USER}}

# Switch to user if created
USER ${CREATE_USER:+${USER}}

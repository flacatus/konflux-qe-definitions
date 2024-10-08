# Builder
FROM registry.access.redhat.com/ubi9/ubi:9.3-1610@sha256:66233eebd72bb5baa25190d4f55e1dc3fff3a9b77186c1f91a0abdb274452072 AS builder

# renovate: datasource=repology depName=homebrew/openshift-cli
ARG OC_VERSION=4.15.9
# renovate: datasource=github-releases depName=openshift/rosa
ARG ROSA_VERSION=v1.2.45
# renovate: datasource=github-releases depName=stedolan/jq
ARG JQ_VERSION=1.6
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=4.43.1

ARG ORAS_VERSION=1.2.0

ARG SHELLCHECK_VERSION=stable

# renovate: datasource=github-releases depName=golangci/golangci-lint
ARG GOLANGCI_LINT_VERSION="v1.59.0"

# utilities
RUN yum -y install xz wget

# Download and install golangci-lint
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s ${GOLANGCI_LINT_VERSION} && \
    cp bin/golangci-lint /usr/local/bin && \
    golangci-lint --version

RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin

RUN wget -qO- "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION?}/shellcheck-${SHELLCHECK_VERSION?}.linux.x86_64.tar.xz" | tar -xJv && \
    cp "shellcheck-${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/ && \
    shellcheck --version

RUN curl -L "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux.tar.gz" -o /tmp/openshift-client-linux.tar.gz && \
    tar --no-same-owner -xzf /tmp/openshift-client-linux.tar.gz && \
    mv oc kubectl /usr/local/bin && \
    oc version --client && \
    kubectl version --client

RUN curl -L "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/rosa/${ROSA_VERSION//v}/rosa-linux.tar.gz" -o /tmp/rosa-linux.tar.gz && \
    tar --no-same-owner -xzf /tmp/rosa-linux.tar.gz && \
    mv rosa /usr/local/bin && \
    rosa version

RUN curl -L "https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64" -o /usr/local/bin/jq  && \
    chmod +x /usr/local/bin/jq && \
    jq --version

RUN curl -L "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    yq --version
RUN curl -LO "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz" && \
    mkdir -p oras-install/ && \
    tar -zxf oras_${ORAS_VERSION}_*.tar.gz -C oras-install/ && \
    mv oras-install/oras /usr/local/bin/ && \
    rm -rf oras_${ORAS_VERSION}_*.tar.gz oras-install/ && \
    oras version

RUN curl -L https://github.com/tektoncd/cli/releases/download/v0.32.2/tkn_0.32.2_Linux_x86_64.tar.gz | tar -xz --no-same-owner -C /usr/local/bin/ tkn && \
    tkn version

# Runnable
FROM registry.access.redhat.com/ubi9/ubi:9.3-1610@sha256:66233eebd72bb5baa25190d4f55e1dc3fff3a9b77186c1f91a0abdb274452072

ENV HOME=/home/tool-box

RUN dnf -y update && \
    dnf -y install git iputils procps-ng python3.11 python3.11-pip vim unzip zip && \
    dnf clean all && \
    pip3.11 install --no-cache-dir yamllint && \
    yamllint --version

COPY --from=builder /usr/local/bin/oc /usr/local/bin/oc
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=builder /usr/local/bin/rosa /usr/local/bin/rosa
COPY --from=builder /usr/local/bin/jq /usr/local/bin/jq
COPY --from=builder /usr/local/bin/yq /usr/local/bin/yq
COPY --from=builder /usr/local/bin/oras /usr/local/bin/oras
COPY --from=builder /usr/local/bin/trufflehog /usr/local/bin/trufflehog
COPY --from=builder /usr/local/bin/shellcheck /usr/local/bin/shellcheck
COPY --from=builder /usr/local/bin/golangci-lint /usr/local/bin/golangci-lint
COPY --from=builder /usr/local/bin/tkn /usr/local/bin/tkn

RUN curl -L https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip && \
    unzip awscliv2.zip && \
    ./aws/install -i /usr/local/aws-cli -b /usr/local/bin && \
    rm -rf awscliv2.zip aws && \
    aws --version

RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh && rm -rf get_helm.sh && \
    curl -Lso /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x /usr/local/bin/kubectl && \
    curl -Lso /usr/local/bin/cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 && chmod +x /usr/local/bin/cosign && \
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

RUN dnf -y --setopt=tsflags=nodocs install \
    git \
    gettext \
    skopeo \
    && dnf clean all

WORKDIR $HOME

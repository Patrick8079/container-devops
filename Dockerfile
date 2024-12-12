FROM docker.io/chainguard/wolfi-base:latest AS builder

ENV ANSIBLE_HOST_KEY_CHECKING="False"
ENV ANSIBLE_SCP_IF_SSH="True"
ENV ANSIBLE_SSH_PIPELINING="True"
ENV PYTHON_VERSION=3.12

WORKDIR /root/

COPY ./ansible-collections/requirements.yml .
COPY ./python-packages/requirements.txt .

RUN apk add --update --no-cache python-${PYTHON_VERSION} py${PYTHON_VERSION}-pip && \
    python3 -m pip --no-cache-dir install --no-compile -r requirements.txt && \
    ansible-galaxy collection install --force -r requirements.yml

RUN pip3 uninstall --yes \
    setuptools \
    && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
    && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

FROM docker.io/chainguard/wolfi-base:latest

ENV ANSIBLE_HOST_KEY_CHECKING="False"
ENV ANSIBLE_SCP_IF_SSH="True"
ENV ANSIBLE_SSH_PIPELINING="True"
ENV PYTHON_VERSION=3.12
ENV TOFU_VERSION=1.8.6
ENV GO_VERSION="1.23.3"
ENV PATH=$PATH:/usr/local/go/bin

WORKDIR /root/

COPY --from=builder /usr/lib/python${PYTHON_VERSION}/site-packages/ /usr/lib/python${PYTHON_VERSION}/site-packages/
COPY --from=builder /root/.ansible/collections /root/.ansible/collections
COPY --from=builder /usr/bin/ansible* /usr/bin

RUN apk add --update --no-cache python-${PYTHON_VERSION} py${PYTHON_VERSION}-pip git openssh sshpass scp unzip gettext findutils jq nmap curl bind-tools wget openldap-clients\
    && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
    && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN curl --proto '=https' --tlsv1.2 -fsSL https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_amd64.apk -o ./tofu_${TOFU_VERSION}_amd64.apk && \
    apk add --allow-untrusted ./tofu_${TOFU_VERSION}_amd64.apk && \
    rm -f ./tofu_${TOFU_VERSION}_amd64.apk

RUN curl --proto '=https' --tlsv1.2 -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -o ./go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm -f ./go${GO_VERSION}.linux-amd64.tar.gz
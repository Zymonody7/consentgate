# AI Hub is distributed only through the InterSystems Early Access Program portal.
# Download the arm64 build for macOS/Apple Silicon, then:
#   docker load -i irishealth_arm64-community-2027.1.0AI.109.0-docker.tar.gz
# and set IMAGE below to the name printed by `docker images`.
ARG IMAGE=docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2027.1.0AI.109.0
FROM $IMAGE

WORKDIR /home/irisowner/dev

ARG NAMESPACE="CONSENTGATE"

ENV IRISUSERNAME "_SYSTEM"
ENV IRISPASSWORD "SYS"
ENV IRISNAMESPACE $NAMESPACE
ENV PYTHON_PATH=/usr/irissys/bin/:/usr/irissys/mgr/python
ENV CONSENTGATE_CONSOLE_DIR=/usr/irissys/csp/console/data

COPY merge.cpf /home/irisowner/dev/merge.cpf

# The reviewer console is a static page served by the container's own web
# server. It must bypass the CSP handler, which owns every other path.
USER root
COPY console /usr/irissys/csp/console
RUN mkdir -p /usr/irissys/csp/console/data && \
    chmod -R 777 /usr/irissys/csp/console && \
    printf 'DirectoryIndex index.html\n<Location /console>\n    CSP Off\n</Location>\n' >> /usr/irissys/httpd/conf/httpd-local.conf
USER irisowner

RUN --mount=type=bind,src=.,dst=. \
    iris start IRIS && \
    iris merge IRIS /home/irisowner/dev/merge.cpf && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly

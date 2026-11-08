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

COPY merge.cpf /home/irisowner/dev/merge.cpf
ENV CONSENTGATE_CONSOLE_DIR=/usr/irissys/csp/console/data
COPY console /usr/irissys/csp/console
RUN printf '<Location /console>\n    CSP Off\n</Location>\n' >> /usr/irissys/httpd/conf/httpd-local.conf

RUN --mount=type=bind,src=.,dst=. \
    iris start IRIS && \
    iris merge IRIS /home/irisowner/dev/merge.cpf && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly

FROM websphere-liberty:kernel

ARG REPOSITORIES_PROPERTIES=""

COPY server.xml /config/

RUN if [ ! -z $REPOSITORIES_PROPERTIES ]; then \
    mkdir /opt/ibm/wlp/etc/ \
    echo $REPOSITORIES_PROPERTIES > /opt/ibm/wlp/etc/repositories.properties; \
  fi \
  && installUtility install --acceptLicense \
    localConnector-1.0 ejbLite-3.2 jsp-2.3 jaxws-2.2  \
  && if [ ! -z $REPOSITORIES_PROPERTIES ]; then rm /opt/ibm/wlp/etc/repositories.properties; fi \
  && rm -rf /output/workarea /output/logs

COPY UserWS.war /config/dropins
# Not clear to me if a lower level image already exposes whether this is needed here
#EXPOSE 9080 9443
# Same goes for the start command if it is already at lower level image
#CMD ["/opt/ibm/wlp/bin/server", "run", "defaultServer"]

# This is too heavyweight but I got too many problems trying to configure a custom image build
FROM registry.eu-gb.bluemix.net/ibmliberty:javaee7

COPY UserWS.war /config/dropins

#EXPOSE 9080 9443

#CMD ["/opt/ibm/wlp/bin/server", "run", "defaultServer"]

# This is too heavyweight but I got too many problems trying to configure a custom image build
FROM registry.eu-gb.bluemix.net/ibmliberty:javaee7

COPY UserWS.war /config/dropins

# Lightweight Alpine JDK
FROM ibmjava:8-jre-alpine
# Install necessary utilities
RUN apk update \
    && apk upgrade \
    && apk add unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy in and unzip the packaged Liberty server
COPY ws.zip /tmp/
RUN unzip -q /tmp/ws.zip -d /opt/ibm \
    && rm /tmp/wlp.zip
# Set PATH env var
ENV PATH=/opt/ibm/wlp/bin:$PATH
EXPOSE 9080 9443
# startup command
CMD ["/opt/ibm/wlp/bin/server", "run", "defaultServer"]

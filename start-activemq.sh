#!/bin/bash

# update broker name for instance
xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --update "//ns:broker/@brokerName" -v $(hostname) /ep/apache-activemq/conf/activemq.xml
if [ $? -ne 0 ]; then
  echo "ERROR: failed to update the broker name. Exiting."
  exit 1
fi

java -Xms${EP_CONTAINER_MEM_ACTIVEMQ}m \
  -Xmx${EP_CONTAINER_MEM_ACTIVEMQ}m \
  -Djava.util.logging.config.file=logging.properties \
  -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote \
  -Djava.io.tmpdir=/ep/apache-activemq/tmp \
  -Dactivemq.classpath=/ep/apache-activemq/conf \
  -Dactivemq.home=/ep/apache-activemq \
  -Dactivemq.base=/ep/apache-activemq \
  -Dactivemq.conf=/ep/apache-activemq/conf \
  -Dactivemq.data=/ep/apache-activemq/data -jar /ep/apache-activemq/bin/activemq.jar start

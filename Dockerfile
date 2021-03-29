#####
# ActiveMQ download stage
#####
FROM amazonlinux:2 AS activemq-downloader
ARG activemqversion=5.15.12

# Update for security and install epel repo
RUN yum update -y && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y clean all && \
    rm -rf /var/cache/yum

# install dependencies
RUN yum update -y && \
    yum install -y aria2 gnutls tar xmlstarlet && \
    yum -y clean all && \
    rm -rf /var/cache/yum

RUN mkdir -p /etc/gnutls/ && \
    echo "SYSTEM=NORMAL" > /etc/gnutls/default-priorities && \#####
# ActiveMQ download stage
#####
FROM amazonlinux:2 AS activemq-downloader
ARG activemqversion=5.15.12

# Update for security and install epel repo
RUN yum update -y && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y clean all && \
    rm -rf /var/cache/yum

# install dependencies
RUN yum update -y && \
    yum install -y aria2 gnutls tar xmlstarlet && \
    yum -y clean all && \
    rm -rf /var/cache/yum

RUN mkdir -p /etc/gnutls/ && \
    echo "SYSTEM=NORMAL" > /etc/gnutls/default-priorities && \
    aria2c --max-connection-per-server=4 --min-split-size=1M \
        https://archive.apache.org/dist/activemq/5.15.12/apache-activemq-${activemqversion}-bin.tar.gz && \
    tar -xzf apache-activemq-5.15.12-bin.tar.gz && \
    rm apache-activemq-5.15.12-bin.tar.gz
RUN mv apache-activemq-5.15.12 apache-activemq

#equalize memory switches
RUN sed -i 's/ACTIVEMQ_OPTS_MEMORY=\"-Xms64M -Xmx1G\"/ACTIVEMQ_OPTS_MEMORY=\"-Xms1G -Xmx1G\"/' '/apache-activemq/bin/env'

# uncomment the sample config
RUN sed -i '/<!-- START SNIPPET: example -->/d' '/apache-activemq/conf/activemq.xml' && \
    sed -i '/<!-- END SNIPPET: example -->/d' '/apache-activemq/conf/activemq.xml'

# Set a finite limit for the storage to deal with EFS and https://issues.apache.org/jira/browse/AMQ-6441
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:storeUsage[last()]" --type attr -n total -v "300 gb" /apache-activemq/conf/activemq.xml
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:tempUsage[last()]" --type attr -n total -v "300 gb" /apache-activemq/conf/activemq.xml

# remove unused transports
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --delete "//ns:transportConnector[@name='ws']" --delete "//ns:transportConnector[@name='mqtt']" --delete "//ns:transportConnector[@name='stomp']" /apache-activemq/conf/activemq.xml

# add auto reload config plugin
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --subnode "//ns:broker" -t elem -n plugins -v "" /apache-activemq/conf/activemq.xml
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --subnode "//ns:plugins" -t elem -n runtimeConfigurationPlugin -v "" /apache-activemq/conf/activemq.xml

RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:runtimeConfigurationPlugin" --type attr -n checkPeriod -v 1000 /apache-activemq/conf/activemq.xml

# let plugins register before start up
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:broker" --type attr -n start -v false /apache-activemq/conf/activemq.xml

# update data directories
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --update "//ns:broker/@dataDirectory" -v "/ep/efs/activemq" /apache-activemq/conf/activemq.xml
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --update "//ns:kahaDB/@directory" -v "/ep/efs/activemq/kahadb" /apache-activemq/conf/activemq.xml

# Modify Kahadb performance settings
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:kahaDB" --type attr -n preallocationScope -v entire_journal_async /apache-activemq/conf/activemq.xml
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:kahaDB" --type attr -n preallocationStrategy -v zeros /apache-activemq/conf/activemq.xml

# only send logs to the console
# this will still create the log file at /root/apache-activemq/data/activemq.log but it will be empty
COPY log4j.properties /apache-activemq/conf/log4j.properties

#####
# Image build
#####
FROM gianlucaperriera/amazonlinux2:latest

RUN mkdir /ep/
COPY --from=activemq-downloader /apache-activemq /ep/apache-activemq

EXPOSE 61612 61613 61616 8161

ADD start-activemq.sh /ep/

CMD ["/ep/start-activemq.sh 2>&1"]

    aria2c --max-connection-per-server=4 --min-split-size=1M \
        https://archive.apache.org/dist/activemq/5.15.12/apache-activemq-${activemqversion}-bin.tar.gz && \
    tar -xzf apache-activemq-5.15.12-bin.tar.gz && \
    rm apache-activemq-5.15.12-bin.tar.gz
RUN mv apache-activemq-5.15.12 apache-activemq

#equalize memory switches
RUN sed -i 's/ACTIVEMQ_OPTS_MEMORY=\"-Xms64M -Xmx1G\"/ACTIVEMQ_OPTS_MEMORY=\"-Xms1G -Xmx1G\"/' '/apache-activemq/bin/env'

# uncomment the sample config
RUN sed -i '/<!-- START SNIPPET: example -->/d' '/apache-activemq/conf/activemq.xml' && \
    sed -i '/<!-- END SNIPPET: example -->/d' '/apache-activemq/conf/activemq.xml'

# Set a finite limit for the storage to deal with EFS and https://issues.apache.org/jira/browse/AMQ-6441
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:storeUsage[last()]" --type attr -n total -v "300 gb" /apache-activemq/conf/activemq.xml
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:tempUsage[last()]" --type attr -n total -v "300 gb" /apache-activemq/conf/activemq.xml

# remove unused transports
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --delete "//ns:transportConnector[@name='ws']" --delete "//ns:transportConnector[@name='mqtt']" --delete "//ns:transportConnector[@name='stomp']" /apache-activemq/conf/activemq.xml

# add auto reload config plugin
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --subnode "//ns:broker" -t elem -n plugins -v "" /apache-activemq/conf/activemq.xml
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --subnode "//ns:plugins" -t elem -n runtimeConfigurationPlugin -v "" /apache-activemq/conf/activemq.xml

RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:runtimeConfigurationPlugin" --type attr -n checkPeriod -v 1000 /apache-activemq/conf/activemq.xml

# let plugins register before start up
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:broker" --type attr -n start -v false /apache-activemq/conf/activemq.xml

# update data directories
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --update "//ns:broker/@dataDirectory" -v "/ep/efs/activemq" /apache-activemq/conf/activemq.xml
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --update "//ns:kahaDB/@directory" -v "/ep/efs/activemq/kahadb" /apache-activemq/conf/activemq.xml

# Modify Kahadb performance settings
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:kahaDB" --type attr -n preallocationScope -v entire_journal_async /apache-activemq/conf/activemq.xml
RUN xmlstarlet ed --inplace -N ns="http://activemq.apache.org/schema/core" --insert "//ns:kahaDB" --type attr -n preallocationStrategy -v zeros /apache-activemq/conf/activemq.xml

# only send logs to the console
# this will still create the log file at /root/apache-activemq/data/activemq.log but it will be empty
COPY log4j.properties /apache-activemq/conf/log4j.properties

#####
# Image build
#####
FROM ${FROM_REPO}/amazonlinux-java:${linuxTag}

RUN mkdir /ep/
COPY --from=activemq-downloader /apache-activemq /ep/apache-activemq

EXPOSE 61612 61613 61616 8161

ADD start-activemq.sh /ep/

CMD ["/ep/start-activemq.sh 2>&1"]

FROM openjdk:8-jdk-stretch

RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

#安装golang1.9.2
ADD https://dl.google.com/go/go1.9.2.linux-amd64.tar.gz /use/local
WORKDIR /use/local
RUN tar -zxvf go1.9.2.linux-amd64.tar.gz -C /usr/local && \
      echo export GOROOT=/usr/local/go >> /etc/profile && \
      echo export GOPATH=/var/jenkins_home >> /etc/profile && \
      echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile && \
      rm -f go1.10.1.linux-amd64.tar.gz && \
      go version && \
      go env
# RUN apt-get install -y golang-1.9 && \
#       echo "export PATH=$PATH:/usr/lib/go-1.9/bin" >> /etc/profile
# COPY sources.list /etc/apt/
# RUN apt-get update --fix-missing &&\
#       apt-get install \
#       apt-transport-https \
#       ca-certificates \
#       curl \
#     software-properties-common
# RUN curl -fsSL https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu/gpg |apt-key add -
# RUN add-apt-repository \
#       "deb [arch=amd64] https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu \
#       $(lsb_release -cs) \
#       stable"
# RUN apt-get update --fix-missing && \
#       apt-get install -y docker-ce


# 安装jenkins
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home

ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN mkdir -p $JENKINS_HOME \
  && chown ${uid}:${gid} $JENKINS_HOME \
  && groupadd -g ${gid} ${group} \
  && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# `/usr/share/jenkins/ref/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes
ARG TINI_VERSION=v0.16.1
COPY tini_pub.gpg ${JENKINS_HOME}/tini_pub.gpg
RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
  && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture).asc -o /sbin/tini.asc \
  && gpg --no-tty --import ${JENKINS_HOME}/tini_pub.gpg \
  && gpg --verify /sbin/tini.asc \
  && rm -rf /sbin/tini.asc /root/.gnupg \
  && chmod +x /sbin/tini
  


# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.121.1}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=5bb075b81a3929ceada4e960049e37df5f15a1e3cfc9dc24d749858e70b48919

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref


      
# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log


USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY tini-shim.sh /bin/tini
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh


USER root
# COPY install-plugins.sh /usr/local/bin/install-plugins.sh
# RUN mkdir -p /usr/share/jenkins
# RUN mkdir -p /usr/local/bin/jenkins-support
# RUN rm -f /usr/share/jenkins/ref/plugins/API.lock
# RUN /usr/local/bin/install-plugins.sh \
#       docker-slaves \
#       Display URL API \
#       GitHub API Plugin \
#       Credentials Plugin \
#       github-branch-source \
#       SSH Credentials Plugin \
#       Apache HttpComponents Client 4.x API Plugin \
# RUN madir -p /var/lib/jenkins/share
RUN chown -R  ${uid}:${gid} /usr/share
RUN chown -R  ${uid}:${gid} /usr/share/jenkins
RUN chown -R  ${uid}:${gid} /usr/share/jenkins/ref/


USER ${user}

# docker run -d -p 8080:8080 -p 50000:50000 -v /wyc/var/lib/jenkins/:/var/jenkins_home --add-host code-cbu.huawei.com:100.101.9.70 3a264caf9ce4

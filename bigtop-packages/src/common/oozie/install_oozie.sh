#!/bin/bash
set -ex

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --extra-dir=DIR    path to Bigtop distribution files
     --build-dir=DIR    path to Bigtop distribution files
     --server-dir=DIR   path to server package root
     --client-dir=DIR   path to the client package root
     --initd-dir=DIR    path to the server init.d directory

  Optional options:
     --docs-dir=DIR     path to the documentation root
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'extra-dir:' \
  -l 'build-dir:' \
  -l 'server-dir:' \
  -l 'client-dir:' \
  -l 'docs-dir:' \
  -l 'initd-dir:' \
  -l 'conf-dir:' \
  -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --extra-dir)
        EXTRA_DIR=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --server-dir)
        SERVER_PREFIX=$2 ; shift 2
        ;;
        --client-dir)
        CLIENT_PREFIX=$2 ; shift 2
        ;;
        --docs-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --initd-dir)
        INITD_DIR=$2 ; shift 2
        ;;
        --conf-dir)
        CONF_DIR=$2 ; shift 2
        ;;
        --)
        shift; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

for var in BUILD_DIR SERVER_PREFIX CLIENT_PREFIX; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

if [ ! -d "${BUILD_DIR}" ]; then
  echo "Build directory does not exist: ${BUILD_DIR}"
  exit 1
fi

## Install client image first
CLIENT_LIB_DIR=${CLIENT_PREFIX}/usr/lib/oozie
MAN_DIR=${CLIENT_PREFIX}/usr/share/man/man1
DOC_DIR=${DOC_DIR:-$CLIENT_PREFIX/usr/share/doc/oozie}
BIN_DIR=${CLIENT_PREFIX}/usr/bin

install -d -m 0755 ${CLIENT_LIB_DIR}
install -d -m 0755 ${CLIENT_LIB_DIR}/bin
cp -R ${BUILD_DIR}/bin/oozie ${CLIENT_LIB_DIR}/bin
cp -R ${BUILD_DIR}/lib ${CLIENT_LIB_DIR}
install -d -m 0755 ${DOC_DIR}
cp -R ${BUILD_DIR}/LICENSE.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/NOTICE.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/oozie-examples.tar.gz ${DOC_DIR}
cp -R ${BUILD_DIR}/README.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/release-log.txt ${DOC_DIR}
[ -f ${BUILD_DIR}/PATCH.txt ] && cp ${BUILD_DIR}/PATCH.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/docs/* ${DOC_DIR}
rm -rf ${DOC_DIR}/target
install -d -m 0755 ${MAN_DIR}
gzip -c ${EXTRA_DIR}/oozie.1 > ${MAN_DIR}/oozie.1.gz

# Create the /usr/bin/oozie wrapper
install -d -m 0755 $BIN_DIR
cat > ${BIN_DIR}/oozie <<EOF
#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

exec /usr/lib/oozie/bin/oozie "\$@"
EOF
chmod 755 ${BIN_DIR}/oozie

[ -d ${SERVER_PREFIX}/usr/bin ] || install -d -m 0755 ${SERVER_PREFIX}/usr/bin
cat > ${SERVER_PREFIX}/usr/bin/oozie-setup <<'EOF'
#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

if [ "$1" == "prepare-war" ]; then
    echo "The prepare-war command is not supported in Apache Bigtop packages."
    exit 1
fi

COMMAND="/usr/lib/oozie/bin/oozie-setup.sh $@"
su -s /bin/bash -c "$COMMAND" oozie
EOF
chmod 755 ${SERVER_PREFIX}/usr/bin/oozie-setup

## Install server image
SERVER_LIB_DIR=${SERVER_PREFIX}/usr/lib/oozie
CONF_DIR=${CONF_DIR:-"${SERVER_PREFIX}/etc/oozie/conf.dist"}
ETC_DIR=${SERVER_PREFIX}/etc/oozie
DATA_DIR=${SERVER_PREFIX}/var/lib/oozie

install -d -m 0755 ${SERVER_LIB_DIR}
install -d -m 0755 ${SERVER_LIB_DIR}/bin
install -d -m 0755 ${DATA_DIR}
for file in ooziedb.sh oozied.sh oozie-sys.sh oozie-setup.sh ; do
  cp ${BUILD_DIR}/bin/$file ${SERVER_LIB_DIR}/bin
done

install -d -m 0755 ${CONF_DIR}
cp -r ${BUILD_DIR}/conf/* ${CONF_DIR}
sed -i -e '/oozie.service.HadoopAccessorService.hadoop.configurations/,/<\/property>/s#<value>\*=hadoop-conf</value>#<value>*=/etc/hadoop/conf</value>#g' \
          ${CONF_DIR}/oozie-site.xml
cp ${EXTRA_DIR}/oozie-env.sh ${CONF_DIR}
install -d -m 0755 ${CONF_DIR}/action-conf
cp ${EXTRA_DIR}/hive.xml ${CONF_DIR}/action-conf
if [ "${INITD_DIR}" != "" ]; then
  install -d -m 0755 ${INITD_DIR}
  cp -R ${EXTRA_DIR}/oozie.init ${INITD_DIR}/oozie
  chmod 755 ${INITD_DIR}/oozie
fi
cp -R ${BUILD_DIR}/oozie-sharelib*.tar.gz ${SERVER_LIB_DIR}/oozie-sharelib.tar.gz
ln -s -f /etc/oozie/conf/oozie-env.sh ${SERVER_LIB_DIR}/bin

cp -R ${BUILD_DIR}/oozie-server/webapps ${SERVER_LIB_DIR}/webapps

# Unpack oozie.war some place reasonable
WEBAPP_DIR=${SERVER_LIB_DIR}/webapps/oozie
mkdir ${WEBAPP_DIR}
(cd ${WEBAPP_DIR} ; jar xf ${BUILD_DIR}/oozie.war)
mv -f ${WEBAPP_DIR}/WEB-INF/lib ${SERVER_LIB_DIR}/libserver
touch ${SERVER_LIB_DIR}/webapps/oozie.war

HTTP_DIRECTORY=${ETC_DIR}/tomcat-deployment.http
install -d -m 0755 ${HTTP_DIRECTORY}
cp -R ${BUILD_DIR}/oozie-server/conf ${HTTP_DIRECTORY}/conf
cp ${EXTRA_DIR}/context.xml ${HTTP_DIRECTORY}/conf/
cp ${EXTRA_DIR}/catalina.properties ${HTTP_DIRECTORY}/conf/
mv ${SERVER_LIB_DIR}/webapps/oozie/WEB-INF ${HTTP_DIRECTORY}/WEB-INF

HTTPS_DIRECTORY=${ETC_DIR}/tomcat-deployment.https
cp -r ${HTTP_DIRECTORY} ${HTTPS_DIRECTORY}
cp ${HTTPS_DIRECTORY}/conf/ssl/ssl-server.xml ${HTTPS_DIRECTORY}/conf/server.xml
cp ${BUILD_DIR}/oozie-server/conf/ssl/ssl-web.xml ${HTTPS_DIRECTORY}/WEB-INF/web.xml

ln -s /usr/lib/oozie/webapps ${ETC_DIR}/tomcat-deployment.http/
ln -s /usr/lib/oozie/webapps ${ETC_DIR}/tomcat-deployment.https/
ln -s /var/lib/oozie/tomcat-deployment/WEB-INF ${SERVER_LIB_DIR}/webapps/oozie/

# Create all the jars needed for tools execution
install -d -m 0755 ${SERVER_LIB_DIR}/libtools
for i in `cd ${BUILD_DIR}/libtools ; ls *` ; do
  if [ -e ${SERVER_LIB_DIR}/libserver/$i ] ; then
    ln -s ../libserver/$i ${SERVER_LIB_DIR}/libtools/$i
  else
    cp ${BUILD_DIR}/libtools/$i ${SERVER_LIB_DIR}/libtools/$i
  fi
done

# Provide a convenience symlink to be more consistent with tarball deployment
ln -s ${DATA_DIR#${SERVER_PREFIX}} ${SERVER_LIB_DIR}/libext


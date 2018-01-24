#!/bin/sh

SHELL_DIR="$( cd "$( dirname "$0"  )" && pwd  )"
echo "Using SHELL_DIR: ${SHELL_DIR}"
RUN_DIR=`pwd`
echo "Using RUN_DIR: ${RUN_DIR}"
ROOT_DIR=${SHELL_DIR}/../..
echo "Using ROOT_DIR: ${ROOT_DIR}"

port="8080"
cluster=0

while getopts p:c opt
do
  case $opt in
    p)
      port="$OPTARG"
    ;;
    c)
      cluster=1
    ;;
  esac
done
shift $((OPTIND-1))

if [ "${JAVA_HOME}" == "" ] ; then
  echo JAVA_HOME environment variable is required.
  exit 1
fi

echo Invoke maven to build all projects...
chmod +x ${SHELL_DIR}/tools/maven/bin/mvn
cd  ${ROOT_DIR}
${SHELL_DIR}/tools/maven/bin/mvn clean install

echo Copy build war to docker war dir...
mkdir -p ${SHELL_DIR}/docker/tomcat/war
\cp -fr ${ROOT_DIR}/docker-webapp/target/entdiy.war ${SHELL_DIR}/docker/tomcat/war/.

echo Startup docker mysql...
chmod +x ${SHELL_DIR}/docker/mysql/bin/*.sh
${SHELL_DIR}/docker/mysql/bin/docker-one.sh restart



echo Startup docker redis...
chmod +x ${SHELL_DIR}/docker/redis/bin/*.sh
${SHELL_DIR}/docker/redis/bin/docker-one.sh restart

echo Deploy webapp to docker...
chmod +x ${SHELL_DIR}/docker/tomcat/bin/*.sh

seconds=10
echo "Sleep ${seconds}s to wait mysql start and execute database init..."
printf "Sleeping ";while(( seconds >0 )); do
  printf .
  ((seconds--))
  sleep 1s
done

echo Init MySQL CREATE DATABASE...
${SHELL_DIR}/docker/tomcat/bin/docker-one.sh init

if [ ${cluster} -eq 1 ] ; then
  ${SHELL_DIR}/docker/tomcat/bin/docker-nodes.sh deploy
else
  echo "Using PORT: ${port}"
  ${SHELL_DIR}/docker/tomcat/bin/docker-one.sh -p ${port} deploy
fi

cd  ${RUN_DIR}
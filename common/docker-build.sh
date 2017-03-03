#!/bin/sh

set -eo pipefail

REV=`git log -n 1 --oneline|cut -d\  -f 1`

function help() {
  echo "docker-build.sh -c <config file>";
  exit 1;
}

CONFIG_FILE="";

while [ $# -ne 0 ]
do
  if [ "$1x" == "-cx" ]; then
    shift;
    CONFIG_FILE="$1";
    shift;
  elif [ "$1x" == "--helpx" ]; then
    help;
  else
    echo "illegal aruguments value.";
    help;
  fi
done

if [ "${CONFIG_FILE}x" == "x" ]; then
  help;
fi

source `dirname $(realpath $0)`/common.conf
source ${CONFIG_FILE}

WORK_DIR=`dirname $(realpath ${CONFIG_FILE})`

if [ "${IMAGE_TAG}x" == "x" -o "${REGISTRY_URL}x" == "x" ]; then
  help
fi

IMAGE_TAG_CHECK=`echo "${IMAGE_TAG}" | sed -E 's#(last|latest)##g'`
if [ "${IMAGE_TAG_CHECK}x" == "x" ]; then
  echo '"last" or "latest" label can not used.';
  exit 2;
fi

cd ${WORK_DIR}

docker build -t ${REGISTRY_URL}/${CONTAINER_NAME}:${IMAGE_TAG}.${REV} --no-cache=true . && \
docker tag ${REGISTRY_URL}/${CONTAINER_NAME}:${IMAGE_TAG}.${REV} ${REGISTRY_URL}/${CONTAINER_NAME}:${IMAGE_TAG} && \

$(aws ecr get-login --region ap-northeast-1) && \

echo "docker push start" && \

docker push ${REGISTRY_URL}/${CONTAINER_NAME}:${IMAGE_TAG} && \

docker rmi ${REGISTRY_URL}/${CONTAINER_NAME}:${IMAGE_TAG} && \

echo "docker push end"

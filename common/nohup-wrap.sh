#!/bin/sh -x

WORK_DIR=`dirname $(realpath $0)`
TARGET_PATH=$1
LOG_NAME=$2

if [ "${TARGET_PATH}x" == "x" ]; then
  echo "Useage : $0 <target_path> <log_file_name>";
  exit 1
fi
if [ "${LOG_NAME}x" == "x" ]; then
  LOG_NAME="/dev/stdout";
fi

echo "build log file name : ${LOG_NAME}"
echo "work directory : ${WORK_DIR}"
echo "target directory : ${TARGET_PATH}"
echo -n "Are you ready to build docker ? [y/n] : "
read INPUT

if [ "${INPUT}x" != "yx" ]; then
  echo "build is stopped."
  exit 0;
fi

cd ${WORK_DIR}

nohup date >> ${LOG_NAME} && ( ( time /bin/sh ./docker-build.sh -c ${TARGET_PATH}/container.prop ) >> ${LOG_NAME} 2>&1; date >> ${LOG_NAME} ) &

echo "build start";

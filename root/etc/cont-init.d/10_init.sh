#!/usr/bin/with-contenv bash

RUN_SCRIPTS=/etc/run1.d
STATUS=0

# Run shell scripts (ending in .sh) in run.d directory

if ls ${RUN_SCRIPTS}/*.sh &>/dev/null; then
  for file in $RUN_SCRIPTS/*.sh; do

    echo "[init] executing ${file}"

    /bin/bash -e $file

    STATUS=$?

    if [[ $STATUS == $SIGNAL_BUILD_STOP ]]; then
      echo "[init] exit signalled - ${file}"
      exit $STATUS
    fi

    if [[ $STATUS != 0 ]]; then
      echo "[init] failed executing - ${file}"
      exit $STATUS
    fi

  done
else
  echo "[init] no run1.d scripts"
fi

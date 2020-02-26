#!/bin/bash

REDIS_PORT=22122
DYNOMITE_PORT=6379

IS_STATEFULSET=1
ORDINAL=""

[[ `hostname` =~ -([0-9]+)$ ]] && ORDINAL=${BASH_REMATCH[1]} || IS_STATEFULSET=0

# If it is a statefulset, there is a master/replica (assume 2 replicas only)
if [ "$IS_STATEFULSET" -eq 1 ]; then

  if [[ $ORDINAL -eq 0 ]]; then
    MASTER="redis-1.redis"
  elif [[ $ORDINAL -eq 1 ]]; then
    MASTER="redis-0.redis"
  else
    exit 1
  fi

  COMPLETED=0
  while : ; do
    # Check whether local Redis is running
    LOCAL_REDIS_STATUS="$(/usr/local/bin/redis-cli -h localhost -p $REDIS_PORT PING)"
    if [[ "${LOCAL_REDIS_STATUS}" =~ 'PONG' ]]; then
      MASTEROFFSET=0
      SLAVEOFFSET=0
      MASTER_EXISTS=0

      # Check whether master exists (try 3 times)
      for i in 1 2 3; do
        REDIS_STATUS="$(/usr/local/bin/redis-cli -h ${MASTER} -p $REDIS_PORT PING)"
        if [[ "${REDIS_STATUS}" =~ 'PONG' ]]; then
          MASTER_EXISTS=1
          break
        fi
        sleep 2
      done

      # If master exists, we sync from master, otherwise it will be an empty instance
      if [[ $MASTER_EXISTS -eq 1 ]]; then
        echo "Master '${MASTER}' exists.."
        # Check whether local dynomite is running
        DYNOMITE_EXISTS=0
        for i in 1 2 3; do
          DYNOMITE_STATUS="$(/usr/local/bin/redis-cli -h localhost -p $DYNOMITE_PORT PING)"
          if [[ "${DYNOMITE_STATUS}" =~ 'PONG' ]]; then
            DYNOMITE_EXISTS=1
            echo "Local Dynomite instance exists.."
            break
          fi
          sleep 2
        done
        # If dynomite is running, set it to "standby"
        if [[ $DYNOMITE_EXISTS -eq 1 ]]; then
          echo "Set local Dynomite instance to 'standby'.."
          curl http://localhost:22222/state/standby
        fi
        echo "Executing: redis-cli -p $REDIS_PORT SLAVEOF $MASTER $REDIS_PORT"
        REDIS_SLAVE="$(/usr/local/bin/redis-cli -p $REDIS_PORT SLAVEOF $MASTER $REDIS_PORT)"
        DONE=0
        while : ; do
          while IFS=$'\n\t' read string; do
            if [[ "$string" =~ 'master_repl_offset:' ]]; then
                MASTEROFFSET=($(echo "${string}" | grep 'master_repl_offset:' | awk -F: '{print $2}' | grep -o "[0-9]*"))
            fi
            if [[ "$string" =~ 'slave_repl_offset:' ]]; then
                SLAVEOFFSET=($(echo "${string}" | grep 'slave_repl_offset:' | awk -F: '{print $2}' | grep -o "[0-9]*"))
            fi
          done < <(/usr/local/bin/redis-cli -p $REDIS_PORT info replication)
          OFFSETDIFF=$(( $MASTEROFFSET - $SLAVEOFFSET))
          echo "master/slave offset: ${MASTEROFFSET} / ${SLAVEOFFSET}"

          # The difference should be less than 10000
          if [[ "$MASTEROFFSET" -gt 0 ]] && [[ "$SLAVEOFFSET" -gt 0 ]]; then
            if [[ "$OFFSETDIFF" -lt 10000 ]]; then
              DONE=1
              # If dynomite is running, set it to "writes_only"
              if [[ $DYNOMITE_EXISTS -eq 1 ]]; then
                echo "Set local Dynomite instance to 'writes_only'.."
                curl http://localhost:22222/state/writes_only
              fi
            fi
          fi
          if [[ "$DONE" -ne 0 ]]; then
            break
          fi
          sleep 2
        done
        # Remove slave
        echo "Executing: redis-cli -p $REDIS_PORT SLAVEOF NO ONE"
        /usr/local/bin/redis-cli -p $REDIS_PORT SLAVEOF NO ONE
        # If dynomite is running, set it to "normal"
        if [[ $DYNOMITE_EXISTS -eq 1 ]]; then
          echo "Set local Dynomite instance to 'normal'.."
          curl http://localhost:22222/state/normal
        fi
      else
        echo "Master '${MASTER}' no found"
      fi
      # Completed
      COMPLETED=1
    fi

    if [[ "$COMPLETED" -ne 0 ]]; then
        echo "Completed."
        break
    fi
    sleep 1
  done
fi


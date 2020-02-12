Redis (Alpine-based) with [Dynomite](https://github.com/Netflix/dynomite) and [S6 overlay](https://github.com/just-containers/s6-overlay).

## Usage

To get started.

### docker

```
docker create \
  --name=docker-alpine-redis \
  -e TZ=UTC \
  --restart unless-stopped \
  qedadmin/alpine-redis
```

## Parameters


| Parameter | Function |
| :---- | --- |
| `-e TZ=UTC` | Set timezone |


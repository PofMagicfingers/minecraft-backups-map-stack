#!/bin/bash

set -ex

RAND=$(openssl rand -hex 3)
SCRIPT=$(basename $0)
OUR_PID=$$

WAIT_TIME=0

while [ "$(docker ps | grep mc_map_generator | wc -l)" -gt 0 ]; do
  echo "[$RAND] map generator is already running"
  ((WAIT_TIME=WAIT_TIME+1))

  if [ "$WAIT_TIME" -gt 5 ]; then
    echo "[$RAND] waited 50s, exiting..."
    exit -1;
    break;
  fi

  sleep 10;
done

date

BASE=$(realpath "$(dirname "$(readlink -f "$BASH_SOURCE")")/..")
MINECRAFT_VERSION=$(find $BASE/minecraft/data -name 'minecraft_server*.jar' | sed -E 's#.*server\.(.*)\.jar#\1#')

if [ -f $BASE/.env ]; then
  echo "[$RAND] loading .env"
  . $BASE/.env
fi

if [ -f $BASE/.env.local ]; then
  echo "[$RAND] loading .env.local"
  . $BASE/.env.local
fi

if [ ! -d $BASE/overviewer/map ]; then
 echo "[$RAND] Creating map directory : $BASE/overviewer/map"
 mkdir -p $BASE/overviewer/map && chown -R $(stat -c '%u:%g' map/) $BASE/overviewer
fi

if ! docker volume inspect mc_map_generator 2>&1 > /dev/null ; then
  echo "[$RAND] Creating map generator cache volume"
  docker volume create mc_map_generator
  docker run --rm -v mc_map_generator:/data alpine chown $(stat -c '%u:%g' $BASE) /data
fi

if [ ! -f $BASE/overviewer/config.py ]; then
  echo "[$RAND] Creating default overviewer config.py"
  docker run --rm mide/minecraft-overviewer cat /home/minecraft/config.py > $BASE/overviewer/config.py
fi

echo "[$RAND] Running docker overviewer with RENDER_MAP=${RENDER_MAP:-true} and MINECRAFT_VERSION = ${MINECRAFT_VERSION}"

docker run \
      --rm \
      -e MINECRAFT_VERSION="$MINECRAFT_VERSION" \
      -e RENDER_MAP="${RENDER_MAP:-true}" \
      -v mc_map_generator:/home/minecraft/.minecraft \
      -v $BASE/overviewer/config.py:/home/minecraft/config.py:ro \
      -v $BASE/minecraft/data/world:/home/minecraft/server/world:ro \
      -v $BASE/overviewer/map:/home/minecraft/render/:rw \
      --name "mc_map_generator_$RAND" \
      mide/minecraft-overviewer

cp -vf $BASE/minecraft/data/server-icon.png $BASE/overviewer/map/favicon.png

if [ "${RENDER_MAP:-true}" == "true" ]; then
  if [ -z "${MC_DISCORD_WH}" ]; then
    echo "[$RAND] set \$MC_DISCORD_WH to add Discord push notifications"
  elif [ -z "${MC_MAP_URL}" ]; then
    echo "[$RAND] set \$MC_MAP_URL to add Discord push notifications"
  else
    curl "$MC_DISCORD_WH" \
    -H "Content-Type: application/json" \
    -d @- <<PAYLOAD
  {
    "username": "${MC_SERVER_NAME:-Minecraft}",
    "avatar_url": "$MC_MAP_URL/favicon.png",
    "embeds": [{
      "title": "??? Carte mise ?? jour ",
      "color": 11027200,
      "fields": [{
        "name": "Ouvrir la carte  ???????",
        "value": "$MC_MAP_URL",
        "inline": true
      }]
    }]
  }
PAYLOAD
  fi
fi

echo "[$RAND] Done."

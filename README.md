# Minecraft server stack

`ln -nfs /path/to/backup/storage/dir minecraft/backups`

`docker compose up -d`

`crontab -e`

```
8,18,28,38,48,58 * * * * /bin/bash -c "/home/minecraft/overviewer/update-map.sh 2>&1" 2>&1 >> /home/minecraft/overviewer/update-map.map.log
* * * * * /bin/bash -c "RENDER_MAP=false /home/minecraft/overviewer/update-map.sh 2>&1" 2>&1 >> /home/minecraft/overviewer/update-map.poi.log
```

## Accès console 

`docker compose exec mc rcon-cli`

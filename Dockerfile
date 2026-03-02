FROM itzg/minecraft-server:latest

# CurseForge modpack install - ATM9 Sky 1.1.8
# CF_API_KEY must be set as a Railway environment variable
ENV EULA=TRUE \
    TYPE=CURSEFORGE \
    CF_PAGE_URL=https://www.curseforge.com/minecraft/modpacks/all-the-mods-9-to-the-sky/files/6079477 \
    VERSION=1.20.1 \
    MEMORY=8G \
    DIFFICULTY=normal \
    MAX_PLAYERS=20 \
    VIEW_DISTANCE=10 \
    SIMULATION_DISTANCE=8 \
    ENABLE_RCON=true \
    RCON_PORT=25575 \
    RCON_PASSWORD=Hackers11!@ \
    MOTD="All the Mods 9 - To the Sky Server" \
    ALLOW_FLIGHT=TRUE \
    SPAWN_PROTECTION=0 \
    ENFORCE_SECURE_PROFILE=FALSE \
    ONLINE_MODE=TRUE

EXPOSE 25565
EXPOSE 25575

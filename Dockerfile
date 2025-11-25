# --- Етап 1: Збірка ---
FROM node:10 AS build

WORKDIR /app

# 1. Фікс репозиторіїв Debian (щоб працював apt-get)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org/|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 2. Системні інструменти
RUN apt-get install -y git python make g++

# 3. Фікс протоколу Git
RUN git config --global url."https://".insteadOf git://

# 4. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 5. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 6. Видаляємо package-lock.json
RUN rm -f package-lock.json

# 7. Встановлюємо npm-залежності без скриптів
RUN npm install --unsafe-perm --ignore-scripts

# 8. Дозбируємо node-sass та Gulp fixes
RUN npm rebuild node-sass && \
    npm install graceful-fs@4 --save-dev --save-exact

# ===================================================
# 9. === ФІКС КОНФЛІКТУ BOWER (Resolutions) ===
# Ми "хитрощами" вписуємо блок resolutions у bower.json.
# Це каже Bower-у: "Не питай мене, просто бери Angular 1.8.3"
# ===================================================
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.8.3" }, "dependencies": {/' bower.json

# 10. Встановлюємо Bower (тепер він не буде питати про версію)
RUN bower install --allow-root --force

# 11. Копіюємо код та збираємо
COPY . .
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

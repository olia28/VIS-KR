# --- Етап 1: Збірка (Node 10) ---
FROM node:10 AS build

WORKDIR /app

# 1. Фікс репозиторіїв Debian (Архів)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org/|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 2. Системні бібліотеки (щоб не падали картинки)
RUN apt-get install -y git python make g++ \
    libpng-dev libjpeg-dev nasm autoconf libtool automake

# 3. Git config
RUN git config --global url."https://".insteadOf git://

# 4. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 5. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 6. Видаляємо сміття
RUN rm -f package-lock.json

# 7. Встановлюємо залежності (без скриптів)
RUN npm install --unsafe-perm --ignore-scripts

# 8. SASS FIX (Ставимо робочу версію)
RUN npm uninstall gulp-sass node-sass --unsafe-perm && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --save-dev --unsafe-perm

# 9. Ребілд залежностей
RUN npm rebuild --unsafe-perm

# 10. Gulp 3 Fix
RUN npm install graceful-fs@4 --save-dev --save-exact

# 11. Bower Fix (Angular Resolution)
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.7.5" }, "dependencies": {/' bower.json

# 12. Bower Install
RUN bower install --allow-root --force

# 13. Копіюємо весь код проекту
COPY . .

# =================================================================
# 14. === ТОЧНА ХІРУРГІЯ (FIXED) ===
# Ми не видаляємо рядки (це ламає синтаксис), а замінюємо текст.
#
# 1. У inject.js прибираємо .pipe($.angularFilesort()), залишаючи дужки масиву цілими.
RUN sed -i 's/\.pipe(\$\.angularFilesort())//g' gulp/inject.js

# 2. У build.js прибираємо ngAnnotate та csso (просто видаляємо виклик pipe).
RUN sed -i 's/\.pipe(\$\.ngAnnotate())//g' gulp/build.js
RUN sed -i 's/\.pipe(\$\.csso())//g' gulp/build.js

# 3. Uglify має параметри, тому ми його коментуємо (//), щоб не розірвати ланцюжок.
RUN sed -i 's/\.pipe(\$\.uglify/\/\/ .pipe(\$.uglify/g' gulp/build.js
# =================================================================

# 15. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build --verbose

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

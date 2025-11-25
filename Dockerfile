# --- Етап 1: Збірка ---
FROM node:10 AS build

WORKDIR /app

# 1. Фікс репозиторіїв Debian (архівні джерела)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org/|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 2. Встановлюємо Python та компілятори (критично для node-sass)
RUN apt-get install -y git python make g++

# 3. Фікс для GitHub протоколу
RUN git config --global url."https://".insteadOf git://

# 4. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 5. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 6. Видаляємо старий lock-файл
RUN rm -f package-lock.json

# 7. Встановлюємо залежності (ігноруємо скрипти, щоб не падав bower)
RUN npm install --unsafe-perm --ignore-scripts

# ===================================================================
# 8. === ХІРУРГІЧНЕ ВТРУЧАННЯ (Вирішення проблеми Sass) ===
# Старий gulp-sass (ver 3.x) тягне поламаний node-sass.
# Ми видаляємо їх і ставимо "Золоту пару", яка працює на Node 10:
# node-sass версії 4.14.1 + gulp-sass версії 4.0.2
# ===================================================================
RUN npm uninstall gulp-sass node-sass --unsafe-perm && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --save-dev --unsafe-perm

# 9. Примусова перекомпіляція Sass під Linux
RUN npm rebuild node-sass

# 10. Лікуємо Gulp 3 (graceful-fs)
RUN npm install graceful-fs@4 --save-dev --save-exact

# 11. Фікс Bower (Resolutions) - щоб Angular не сварився на версії
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.7.5" }, "dependencies": {/' bower.json

# 12. Тепер запускаємо Bower
RUN bower install --allow-root --force

# 13. Копіюємо решту файлів
COPY . .

# 14. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

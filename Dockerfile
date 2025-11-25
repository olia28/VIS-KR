# --- Етап 1: Збірка ---
FROM node:10 AS build

WORKDIR /app

# 1. Фікс репозиторіїв Debian (щоб працював apt-get)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org/|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 2. === ВАЖЛИВО: ВСТАНОВЛЕННЯ ВСІХ МОЖЛИВИХ БІБЛІОТЕК ===
# Ми додаємо libpng, nasm, autoconf - це потрібно для gulp-imagemin
# Без них збірка падає мовчки.
RUN apt-get install -y git python make g++ \
    libpng-dev libjpeg-dev autoconf libtool nasm automake libglu1-mesa

# 3. Налаштування Git
RUN git config --global url."https://".insteadOf git://

# 4. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 5. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 6. Видаляємо package-lock.json
RUN rm -f package-lock.json

# 7. Встановлюємо залежності (ігноруємо скрипти)
RUN npm install --unsafe-perm --ignore-scripts

# 8. === ФІКС SASS ===
# Видаляємо старий, ставимо стабільний для Node 10
RUN npm uninstall gulp-sass node-sass --unsafe-perm && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --save-dev --unsafe-perm

# 9. === ТОТАЛЬНИЙ РЕБІЛД ===
# Перезбираємо ВСІ залежності (і Sass, і Imagemin, і PhantomJS)
RUN npm rebuild --unsafe-perm

# 10. Лікуємо Gulp 3
RUN npm install graceful-fs@4 --save-dev --save-exact

# 11. Фікс Bower
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.7.5" }, "dependencies": {/' bower.json

# 12. Встановлюємо Bower
RUN bower install --allow-root --force

# 13. Копіюємо проект
COPY . .

# 14. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
# Додаємо прапорець --verbose, щоб якщо впаде, ми хоч побачили чому
RUN gulp build --verbose

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

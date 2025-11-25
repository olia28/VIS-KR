# --- Етап 1: Збірка ---
FROM node:10 AS build

WORKDIR /app

# 1. Фікс репозиторіїв Debian (щоб працював apt-get)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org/|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 2. Системні інструменти (потрібні для збірки Sass)
RUN apt-get install -y git python make g++

# 3. Налаштування Git
RUN git config --global url."https://".insteadOf git://

# 4. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 5. Копіюємо тільки файли залежностей
COPY package*.json bower.json* .bowerrc* ./

# 6. Видаляємо package-lock.json (він часто створює проблеми в старих проектах)
RUN rm -f package-lock.json

# 7. Встановлюємо залежності, ігноруючи скрипти (щоб не запускався bower завчасно)
RUN npm install --unsafe-perm --ignore-scripts

# 8. === ГОЛОВНИЙ ФІКС ===
# Ми примусово встановлюємо node-sass версії 4.14.1.
# Це єдина версія, яка стабільно працює на Node 10 і не "падає" мовчки.
RUN npm install node-sass@4.14.1 --save-dev --unsafe-perm

# 9. Перезбираємо node-sass під Linux середовище
RUN npm rebuild node-sass

# 10. Лікуємо Gulp 3 (graceful-fs)
RUN npm install graceful-fs@4 --save-dev --save-exact

# 11. Копіюємо ВЕСЬ проект (Тільки зараз, щоб не перезаписати node_modules)
COPY . .

# 12. Фікс конфлікту версій для Bower (Angular 1.8.3)
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.8.3" }, "dependencies": {/' bower.json

# 13. Запускаємо Bower (тепер, коли всі файли на місці)
RUN bower install --allow-root --force

# 14. Збірка
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

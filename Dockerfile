# --- Етап 1: Збірка ---
# Використовуємо Node 12 (Buster) - це стабільна база з робочими репозиторіями
FROM node:12-buster AS build

WORKDIR /app

# 1. Встановлюємо "Важку артилерію" системних бібліотек.
# Ці бібліотеки критичні для gulp-imagemin та Sass.
# На Node 12 вони встановлюються коректно (на відміну від Node 10).
RUN apt-get update && apt-get install -y \
    git python make g++ \
    libpng-dev libjpeg-dev libgifsicle \
    autoconf libtool nasm automake libglu1-mesa

# 2. Фікс для Git
RUN git config --global url."https://".insteadOf git://

# 3. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 4. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 5. Видаляємо старий лок-файл
RUN rm -f package-lock.json

# 6. === ПАТЧ ДЛЯ GULP 3 НА NODE 12 ===
# На Node 12 Gulp 3 падає з помилкою "primordials".
# Ми створюємо файл npm-shrinkwrap.json, щоб примусово замінити fs-модуль.
RUN echo '{ "dependencies": { "graceful-fs": { "version": "4.2.11" } } }' > npm-shrinkwrap.json

# 7. Встановлюємо залежності (ігноруємо скрипти, щоб не падав bower)
RUN npm install --unsafe-perm --ignore-scripts

# 8. === ПРИМУСОВИЙ АПГРЕЙД SASS ===
# Старий gulp-sass не працюватиме. Ми ставимо сумісну пару.
RUN npm uninstall gulp-sass node-sass --unsafe-perm && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --save-dev --unsafe-perm

# 9. Перезбираємо все під нову систему
RUN npm rebuild --unsafe-perm

# 10. Фікс Bower для Angular
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.7.5" }, "dependencies": {/' bower.json

# 11. Запускаємо Bower
RUN bower install --allow-root --force

# 12. Копіюємо код
COPY . .

# 13. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build --verbose

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

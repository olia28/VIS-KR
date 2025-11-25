# --- Етап 1: Збірка ---
# Використовуємо Node 14 (Bullseye). Його репозиторії ЖИВІ.
# Це вирішує проблему "404 Not Found" назавжди.
FROM node:14-bullseye AS build

WORKDIR /app

# 1. Встановлюємо системні бібліотеки.
# Тут ми ставимо "важку артилерію" для графіки (libpng, nasm), щоб Gulp не падав мовчки.
# Ніяких sed/archive hack не треба - все працює штатно.
RUN apt-get update && apt-get install -y \
    git python3 make g++ \
    libpng-dev libjpeg-dev libgifsicle \
    autoconf libtool nasm automake libglu1-mesa

# 2. Налаштування Git
RUN git config --global url."https://".insteadOf git://

# 3. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 4. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 5. Видаляємо старий лок-файл
RUN rm -f package-lock.json

# 6. === ПАТЧ СУМІСНОСТІ (Node 14 + Gulp 3) ===
# Це найважливіший рядок. Він створює файл, який "лікує" Gulp 3
# від помилки "ReferenceError: primordials is not defined".
RUN echo '{ "dependencies": { "graceful-fs": { "version": "4.2.11" } } }' > npm-shrinkwrap.json

# 7. Встановлюємо залежності (ігноруємо скрипти)
RUN npm install --unsafe-perm --ignore-scripts

# 8. === ПРИМУСОВИЙ АПГРЕЙД SASS ===
# Node 14 потребує новішої версії Sass. Ми її ставимо примусово.
RUN npm uninstall gulp-sass node-sass --unsafe-perm && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --save-dev --unsafe-perm

# 9. Перезбираємо все під нову систему (Node 14)
RUN npm rebuild --unsafe-perm

# 10. Фікс Bower для Angular (щоб не сварився на версії)
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.7.5" }, "dependencies": {/' bower.json

# 11. Запускаємо Bower
RUN bower install --allow-root --force

# 12. Копіюємо код
COPY . .

# 13. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
# --verbose покаже нам все, що відбувається
RUN gulp build --verbose

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

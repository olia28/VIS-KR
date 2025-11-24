# Використовуємо Node 12 (Buster)
FROM node:12-buster as build
WORKDIR /app

# 1. === ВИПРАВЛЕННЯ АРХІВІВ (Buster) ===
# Debian 10 застарів, тому ми перемикаємося на архівні дзеркала.
# Без цього apt-get update видає 404.
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git build-essential python make g++ libpng-dev nasm autoconf libtool automake zlib1g-dev

# 2. Налаштовуємо Git
RUN git config --global url."https://".insteadOf git://

# 3. Встановлюємо інструменти
RUN npm install -g gulp-cli bower

COPY . .

# 4. Чистимо сміття
RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

# 5. Встановлюємо залежності
RUN npm install --unsafe-perm

# 6. === ЛІКУВАННЯ GULP 3 ===
# Це обов'язково для Node 12+, інакше Gulp впаде з помилкою "primordials"
RUN npm install graceful-fs@4 --save-dev --unsafe-perm

# 7. Оновлюємо та перебудовуємо Sass
RUN npm uninstall gulp-sass node-sass && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --unsafe-perm && \
    npm rebuild node-sass

# 8. Запускаємо Bower
RUN bower install --allow-root --force

# 9. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# Етап 2: NGINX
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

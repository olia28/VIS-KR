# Використовуємо Node 10 на базі Debian Buster (стабільніша версія)
FROM node:10-buster as build
WORKDIR /app

# 1. Налаштовуємо архіви для Debian Buster (він переміщений в архів)
# Це виправить помилки "404 Not Found" при встановленні програм
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git build-essential python make g++ libpng-dev nasm autoconf libtool automake zlib1g-dev

# 2. Налаштовуємо Git (HTTPS замість GIT)
RUN git config --global url."https://".insteadOf git://

# 3. Встановлюємо Gulp та Bower
RUN npm install -g gulp-cli bower

COPY . .

# 4. Чистимо сміття
RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

# 5. Встановлюємо залежності
RUN npm install --unsafe-perm

# 6. === РЕМОНТ SASS ===
# Видаляємо стару версію і ставимо сумісну з Node 10
RUN npm uninstall gulp-sass node-sass && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --unsafe-perm && \
    npm install graceful-fs@4 --save-dev --unsafe-perm

# 7. Перезбираємо Sass під цю систему
RUN npm rebuild node-sass

# 8. Запускаємо Bower
RUN bower install --allow-root --force

# 9. Збірка
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# Етап 2: NGINX
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

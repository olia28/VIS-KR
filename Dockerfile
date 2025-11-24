# 1. Міняємо базовий образ на Buster (він новіший, але з Node 10)
FROM node:10-buster as build
WORKDIR /app

# 2. Налаштовуємо архіви для Buster (він теж вже в архіві)
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git build-essential python make g++ libpng-dev nasm autoconf libtool automake zlib1g-dev libjpeg62-turbo-dev libgif-dev optipng gifsicle

# 3. Налаштовуємо Git
RUN git config --global url."https://".insteadOf git://
RUN npm install -g gulp-cli bower

COPY . .

# 4. Чистимо сміття
RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

# 5. Встановлюємо залежності
RUN npm install --unsafe-perm

# 6. Виправляємо Sass і Gulp (стандартний набір)
RUN npm install graceful-fs@4 --save-dev --unsafe-perm
RUN npm uninstall gulp-sass node-sass
RUN npm install node-sass@4.14.1 gulp-sass@4.0.2 --unsafe-perm

# 7. === ВАЖЛИВО ===
# Робимо повний ребілд всього на новій системі
RUN npm rebuild

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

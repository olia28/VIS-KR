FROM node:10-stretch as build
WORKDIR /app

# 1. Налаштовуємо архіви Debian (щоб працював apt-get)
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git build-essential python make g++ libpng-dev libjpeg62-turbo-dev libgif-dev nasm autoconf libtool automake zlib1g-dev

# 2. Налаштовуємо Git
RUN git config --global url."https://".insteadOf git://

# 3. Встановлюємо глобальні інструменти
RUN npm install -g gulp-cli bower

COPY . .

# 4. Чистимо проект від сміття з Windows
RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

# 5. Встановлюємо залежності
RUN npm install --unsafe-perm

# 6. Лагодимо Gulp та Sass
RUN npm install graceful-fs@4 --save-dev --unsafe-perm
RUN npm uninstall gulp-sass node-sass
RUN npm install node-sass@4.14.1 gulp-sass@4.0.2 --unsafe-perm

# 7. === ГОЛОВНЕ ВИПРАВЛЕННЯ ===
# Ми запускаємо повний ребілд ВСІХ пакетів. 
# Це полагодить не тільки sass, а й imagemin, pngquant та інші графічні інструменти, 
# які найчастіше викликають "тиху смерть" збірки.
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

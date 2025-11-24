FROM node:10-stretch as build
WORKDIR /app

# 1. Встановлюємо базові інструменти
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git build-essential python make g++

# 2. Налаштування Git та npm
RUN git config --global url."https://".insteadOf git://
RUN npm install -g gulp-cli bower

COPY . .

# 3. Чистимо та готуємо package.json
RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

# 4. Встановлюємо залежності
RUN npm install --unsafe-perm

# 5. === ГОЛОВНИЙ ХАК: ВИМИКАЄМО СТИСНЕННЯ КАРТИНОК ===
# Ми знаходимо файл gulp/build.js і видаляємо з нього згадку про 'imagemin' або 'cache'.
# Це змусить Gulp просто копіювати картинки, не намагаючись їх стиснути бінарниками, які падають.
# (Ця команда замінює pipe($.cache($.imagemin...)) на ніщо)
RUN sed -i '/pipe($.cache($.imagemin/,/pipe(gulp.dest/d' gulp/build.js && \
    sed -i '/return gulp.src/a .pipe(gulp.dest(paths.dist + "/assets/images/"));' gulp/build.js

# 6. Лагодимо Gulp та Sass
RUN npm install graceful-fs@4 --save-dev --unsafe-perm
RUN npm uninstall gulp-sass node-sass
RUN npm install node-sass@4.14.1 gulp-sass@4.0.2 --unsafe-perm
RUN npm rebuild node-sass

# 7. Запускаємо Bower
RUN bower install --allow-root --force

# 8. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# Етап 2: NGINX
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

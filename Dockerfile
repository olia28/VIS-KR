# 1. Використовуємо Node 12 (Buster) - він стабільніший за Stretch
FROM node:12-buster as build
WORKDIR /app

# 2. Встановлюємо Python 2 (потрібен для Gulp 3) та інструменти збірки
RUN apt-get update && \
    apt-get install -y git build-essential python make g++ libpng-dev nasm autoconf libtool automake zlib1g-dev

RUN git config --global url."https://".insteadOf git://
RUN npm install -g gulp-cli bower

COPY . .

# 3. Чистимо проект від сміття
RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

# 4. Встановлюємо залежності
RUN npm install --unsafe-perm

# 5. === КРИТИЧНИЙ ФІКС ДЛЯ GULP 3 НА NODE 12 ===
# Gulp 3 не працює на Node 12 без цього модуля.
# Це вирішує проблему "ReferenceError: primordials is not defined"
RUN npm install graceful-fs@4 --save-dev --unsafe-perm

# 6. Оновлюємо Sass до версії, яка любить Node 12
RUN npm uninstall gulp-sass node-sass && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --unsafe-perm && \
    npm rebuild node-sass

# 7. Запускаємо Bower
RUN bower install --allow-root --force

# 8. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

FROM node:10-alpine as build
WORKDIR /app

# 1. Встановлюємо інструменти збірки для Alpine Linux
# python, make, g++ потрібні для node-sass
RUN apk add --no-cache git python make g++ bash

# 2. Налаштування Git
RUN git config --global url."https://".insteadOf git://

# 3. Встановлюємо глобальні інструменти
RUN npm install -g gulp-cli bower

COPY . .

# 4. Чистимо сміття
RUN rm -rf node_modules package-lock.json
# Ця команда для sed трохи відрізняється в Alpine, тому ми використовуємо простіший варіант
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

# 5. Встановлюємо залежності
# --unsafe-perm критичний для Alpine
RUN npm install --unsafe-perm

# 6. === КРИТИЧНИЙ КРОК ===
# Ми примусово оновлюємо Sass на версію, яка гарантовано працює на Node 10 Alpine
# І додаємо graceful-fs для Gulp
RUN npm install graceful-fs@4 --save-dev --unsafe-perm && \
    npm uninstall gulp-sass node-sass && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --unsafe-perm

# 7. Ребілд для Alpine
RUN npm rebuild node-sass

# 8. Bower
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

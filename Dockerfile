FROM node:10-stretch as build
WORKDIR /app

# 1. Виправляємо репозиторії Debian Stretch (архівні)
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list

# 2. Встановлюємо ВАЖКІ графічні бібліотеки
# Це критично: ми ставимо optipng, gifsicle, libjpeg, щоб Gulp не падав при обробці картинок
RUN apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git build-essential python make g++ libpng-dev libjpeg62-turbo-dev libgif-dev nasm autoconf libtool automake zlib1g-dev optipng gifsicle

RUN git config --global url."https://".insteadOf git://
RUN npm install -g gulp-cli bower

COPY . .

# 3. Чистимо сміття та налаштовуємо package.json
RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

# 4. Налаштовуємо npm на роботу від root
RUN npm config set unsafe-perm true

# 5. Встановлюємо залежності (використовуємо рідні версії з package.json)
RUN npm install

# 6. Лагодимо Gulp 3 для Node 10
RUN npm install graceful-fs@4 --save-dev

# 7. ПРИМУСОВО перезбираємо node-sass під це середовище
# Це краще, ніж міняти версію вручну, бо зберігає сумісність з кодом проекту
RUN npm rebuild node-sass

# 8. Запускаємо Bower
RUN bower install --allow-root --force

# 9. Запускаємо збірку з розширеною пам'яттю
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

# --- Етап 1: Збірка ---
FROM node:10 AS build

WORKDIR /app

# 1. Фікс репозиторіїв Debian (щоб не було 404 помилки)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org/|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 2. Встановлюємо системні залежності
RUN apt-get install -y git python make g++

# 3. Фікс для git (GitHub)
RUN git config --global url."https://".insteadOf git://

# 4. Встановлюємо інструменти
RUN npm install -g gulp-cli bower

# 5. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 6. Видаляємо сміття
RUN rm -f package-lock.json

# 7. === ГОЛОВНИЙ ФІКС ===
# --ignore-scripts: Забороняє npm автоматично запускати "bower install", який ламає все.
RUN npm install --unsafe-perm --ignore-scripts

# 8. Оскільки ми вимкнули скрипти, треба вручну зібрати node-sass
RUN npm rebuild node-sass

# 9. Лікуємо Gulp 3
RUN npm install graceful-fs@4 --save-dev --save-exact

# 10. Вручну запускаємо Bower з дозволом root
RUN bower install --allow-root

# 11. Копіюємо код і збираємо
COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

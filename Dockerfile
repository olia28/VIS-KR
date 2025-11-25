# Використовуємо node:10 (Debian Stretch)
FROM node:10 AS build

WORKDIR /app

# === ФІКС ДЛЯ DEBIAN STRETCH ===
# Оскільки ця версія Linux стара, репозиторії переїхали в архів.
# Ми змінюємо адреси джерел, щоб apt-get update не видавав помилку 404.
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org/|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 1. Тепер apt-get працює. Встановлюємо Python та інструменти
RUN apt-get install -y git python make g++

# 2. Фікс для git протоколу (якщо bower стукає по git://)
RUN git config --global url."https://".insteadOf git://

# 3. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 4. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 5. Видаляємо старий лок-файл, щоб не заважав
RUN rm -f package-lock.json

# 6. Встановлюємо залежності (дозволяємо root для node-sass)
RUN npm install --unsafe-perm

# 7. Фікс для Gulp 3 (graceful-fs) - це "магія", щоб він не падав на Node 10+
RUN npm install graceful-fs@4 --save-dev --save-exact

# 8. Bower
RUN bower install --allow-root

# 9. Копіюємо код
COPY . .

# 10. Збірка
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# --- Етап 2: NGINX ---
FROM nginx:alpine

COPY --from=build /app/dist /usr/share/nginx/html

# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

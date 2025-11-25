# --- Етап 1: Збірка ---
# Використовуємо повну версію Node 10 (Debian), а не Alpine.
# Це вирішує 99% проблем з компіляцією node-sass.
FROM node:10 AS build

WORKDIR /app

# 1. Встановлюємо Python та інструменти збірки
RUN apt-get update && apt-get install -y git python make g++

# 2. Виправляємо проблему з протоколом git:// (GitHub його більше не підтримує)
# Це критично для bower install
RUN git config --global url."https://".insteadOf git://

# 3. Встановлюємо глобальні інструменти
RUN npm install -g gulp-cli bower

# 4. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 5. ВАЖЛИВО: Видаляємо старий package-lock, бо він блокує встановлення правильних версій
RUN rm -f package-lock.json

# 6. Спочатку встановлюємо залежності. 
# --unsafe-perm дозволяє скриптам виконуватися від root (потрібно для Docker)
RUN npm install --unsafe-perm

# 7. ЛАЙФХАК: Примусово оновлюємо graceful-fs.
# Gulp 3 ламається на нових системах без цього фіксу.
# Ми робимо це окремим кроком, щоб переписати те, що встановив npm install.
RUN npm install graceful-fs@4 --save-dev --save-exact

# 8. Встановлюємо фронтенд-залежності через Bower
RUN bower install --allow-root

# 9. Копіюємо код проекту
COPY . .

# 10. Збірка
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

# --- Етап 2: NGINX ---
FROM nginx:alpine

# Копіюємо зібраний проект
COPY --from=build /app/dist /usr/share/nginx/html

# Якщо у вас немає файлу nginx.conf у репозиторії, цей рядок викличе помилку.
# Я його закоментував. Якщо файл є - розкоментуйте.
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

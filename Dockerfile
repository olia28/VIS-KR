# --- Етап 1: Збірка (Build Stage) ---
FROM node:14-bullseye AS build

WORKDIR /app

# Встановлюємо системні залежності для node-sass та старих збірок
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

# Встановлюємо Gulp глобально
RUN npm install -g gulp-cli

# Копіюємо файли package.json
COPY package*.json ./

# Встановлюємо залежності з прапорцем legacy-peer-deps для сумісності
RUN npm install --legacy-peer-deps

# Копіюємо весь проект
COPY . .

# Збільшуємо ліміт пам'яті Node.js
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Запускаємо збірку
RUN gulp build

# --- Етап 2: Сервер (NGINX) ---
FROM nginx:alpine

# Копіюємо результат збірки (папка dist) в Nginx
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

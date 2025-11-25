FROM node:18-alpine AS build
WORKDIR /app

# Встановлення залежностей
RUN apk add --no-cache git python3 make g++

# Глобальні інструменти
RUN npm install -g gulp-cli bower

# Копіюємо dependency файли
COPY package*.json bower.json .bowerrc* ./

RUN npm install
RUN bower install --allow-root --force

# Копіюємо код
COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN gulp build

# ------- Production image --------
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

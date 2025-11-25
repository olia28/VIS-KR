# --- Етап 1: Збірка (Node 18) ---
FROM node:18-alpine AS build

WORKDIR /app

# Копіюємо файли залежностей
COPY package.json package-lock.json ./

# Встановлюємо залежності (швидко і надійно)
RUN npm ci

# Копіюємо весь код
COPY . .

# Збираємо проект (стандартна команда Angular)
RUN npm run build

# --- Етап 2: Сервер (NGINX) ---
FROM nginx:alpine

# Копіюємо зібрані файли.
# У CoreUI папка збірки зазвичай називається dist/coreui-free-angular-admin-template
# Ми копіюємо вміст цієї папки в NGINX
COPY --from=build /app/dist/coreui-free-angular-admin-template /usr/share/nginx/html

# Копіюємо конфіг nginx (необов'язково, але корисно для Angular роутингу)
# Можна використати стандартний, якщо не хочете створювати файл.
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

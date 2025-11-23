FROM node:14-bullseye as build
WORKDIR /app

COPY package*.json ./

RUN npm install --legacy-peer-deps

COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN ./node_modules/.bin/ng build --prod

FROM nginx:alpine
COPY --from=build /app/dist/my-dashboard-project /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

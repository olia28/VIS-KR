FROM node:14-bullseye as build
WORKDIR /app

COPY package*.json ./

RUN npm install --legacy-peer-deps

RUN npm install -g @angular/cli@13

COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN ng build --configuration production

FROM nginx:alpine
COPY --from=build /app/dist/angular-material-dashboard /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

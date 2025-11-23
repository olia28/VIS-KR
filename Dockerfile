FROM node:10-stretch as build
WORKDIR /app

RUN apt-get update && apt-get install -y git

RUN npm install -g gulp-cli bower

COPY package*.json bower.json .bowerrc* ./

RUN npm install --unsafe-perm

COPY . .

RUN gulp build

FROM nginx:alpine

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

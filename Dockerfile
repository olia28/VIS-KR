FROM node:14-bullseye as build
WORKDIR /app

RUN apt-get update && \
    apt-get install -y git build-essential python make g++ libpng-dev nasm autoconf libtool automake zlib1g-dev

RUN git config --global url."https://".insteadOf git://
RUN npm install -g gulp-cli bower

COPY . .

RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

RUN npm install --unsafe-perm --ignore-scripts

RUN npm install graceful-fs@4 --save-dev
RUN npm uninstall gulp-sass node-sass
RUN npm install node-sass@4.14.1 gulp-sass@4.0.2 --unsafe-perm
RUN npm rebuild

RUN bower install --allow-root --force

ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

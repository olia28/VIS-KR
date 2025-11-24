FROM node:10-stretch as build
WORKDIR /app

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git build-essential python make g++

RUN git config --global url."https://".insteadOf git://

RUN npm install -g gulp-cli bower

COPY package*.json bower.json .bowerrc* ./

RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

RUN npm install --unsafe-perm

RUN npm install graceful-fs@4 --save-dev --unsafe-perm

RUN npm uninstall gulp-sass node-sass && \
    npm install node-sass@4.14.1 --unsafe-perm && \
    npm install gulp-sass@4.0.1 --unsafe-perm

RUN bower install --allow-root --force

COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN gulp build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

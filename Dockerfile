FROM node:10-stretch as build
WORKDIR /app

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git build-essential python make g++ libpng-dev nasm autoconf libtool automake zlib1g-dev

RUN git config --global url."https://".insteadOf git://
RUN npm install -g gulp-cli bower

COPY . .

RUN rm -rf node_modules package-lock.json
RUN sed -i 's/"bower install"/"echo skipping bower install"/' package.json

RUN npm install --unsafe-perm

RUN npm rebuild node-sass

RUN bower install --allow-root --force

ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

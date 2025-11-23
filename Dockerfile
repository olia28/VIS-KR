FROM node:10-stretch as build
WORKDIR /app

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y git

RUN git config --global url."https://".insteadOf git://

RUN npm install -g gulp-cli bower

COPY package*.json bower.json .bowerrc* ./

RUN sed -i '/"install": "bower install"/d' package.json

RUN npm install --unsafe-perm

RUN bower install --allow-root --force

COPY . .

RUN gulp build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

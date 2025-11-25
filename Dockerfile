# --- Етап 1: Збірка (Node 10) ---
FROM node:10 AS build

WORKDIR /app

# 1. Фікс репозиторіїв Debian
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org/|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 2. Системні бібліотеки
RUN apt-get install -y git python make g++ \
    libpng-dev libjpeg-dev nasm autoconf libtool automake

# 3. Git config
RUN git config --global url."https://".insteadOf git://

# 4. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 5. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 6. Видаляємо сміття
RUN rm -f package-lock.json

# 7. Встановлюємо залежності
RUN npm install --unsafe-perm --ignore-scripts

# 8. SASS FIX
RUN npm uninstall gulp-sass node-sass --unsafe-perm && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --save-dev --unsafe-perm

# 9. Ребілд
RUN npm rebuild --unsafe-perm

# 10. Gulp 3 Fix
RUN npm install graceful-fs@4 --save-dev --save-exact

# 11. Bower Fix
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.7.5" }, "dependencies": {/' bower.json

# 12. Bower Install
RUN bower install --allow-root --force

# 13. Копіюємо весь код
COPY . .

# =================================================================
# 14. === ПОВНА ЗАМІНА ФАЙЛІВ ЗБІРКИ (TOTAL OVERWRITE) ===
# Ми створюємо "безпечні" версії файлів build.js та inject.js.
# В них ВИДАЛЕНІ: uglify, csso, ngAnnotate, angularFilesort, rev.
# Це гарантує, що збірка не впаде через брак пам'яті чи помилки парсингу.
# =================================================================

# --- Перезаписуємо gulp/inject.js ---
RUN cat <<EOF > gulp/inject.js
'use strict';
var gulp = require('gulp');
var paths = gulp.paths;
var $ = require('gulp-load-plugins')();
var wiredep = require('wiredep').stream;

gulp.task('inject', ['styles'], function () {
  var injectStyles = gulp.src([
    paths.tmp + '/serve/{app,components}/**/*.css',
    '!' + paths.tmp + '/serve/app/vendor.css'
  ], { read: false });

  var injectScripts = gulp.src([
    paths.src + '/{app,components}/**/*.js',
    '!' + paths.src + '/{app,components}/**/*.spec.js',
    '!' + paths.src + '/{app,components}/**/*.mock.js'
  ]); 
  // ПРИБРАНО: .pipe($.angularFilesort()) - воно падало

  var injectOptions = {
    ignorePath: [paths.src, paths.tmp + '/serve'],
    addRootSlash: false
  };

  var wiredepOptions = {
    directory: 'bower_components',
    exclude: [/bootstrap\.css/, /foundation\.css/]
  };

  return gulp.src(paths.src + '/*.html')
    .pipe($.inject(injectStyles, injectOptions))
    .pipe($.inject(injectScripts, injectOptions))
    .pipe(wiredep(wiredepOptions))
    .pipe(gulp.dest(paths.tmp + '/serve'));
});
EOF

# --- Перезаписуємо gulp/build.js ---
RUN cat <<EOF > gulp/build.js
'use strict';
var gulp = require('gulp');
var paths = gulp.paths;
var $ = require('gulp-load-plugins')({
  pattern: ['gulp-*', 'main-bower-files', 'uglify-save-license', 'del']
});

gulp.task('partials', function () {
  return gulp.src([
    paths.src + '/{app,components}/**/*.html',
    paths.tmp + '/{app,components}/**/*.html'
  ])
    .pipe($.minifyHtml({ empty: true, spare: true, quotes: true }))
    .pipe($.angularTemplatecache('templateCacheHtml.js', {
      module: 'angularMaterialAdmin'
    }))
    .pipe(gulp.dest(paths.tmp + '/partials/'));
});

gulp.task('html', ['inject', 'partials'], function () {
  var partialsInjectFile = gulp.src(paths.tmp + '/partials/templateCacheHtml.js', { read: false });
  var partialsInjectOptions = {
    starttag: '',
    ignorePath: paths.tmp + '/partials',
    addRootSlash: false
  };

  var assets;

  return gulp.src(paths.tmp + '/serve/*.html')
    .pipe($.inject(partialsInjectFile, partialsInjectOptions))
    .pipe(assets = $.useref.assets())
    // ТУТ БУЛИ: rev, ngAnnotate, uglify, csso - МИ ЇХ ВИДАЛИЛИ
    .pipe(assets.restore())
    .pipe($.useref())
    .pipe(gulp.dest(paths.dist + '/'))
    .pipe($.size({ title: paths.dist + '/', showFiles: true }));
});

gulp.task('images', function () {
  return gulp.src(paths.src + '/assets/images/**/*')
    .pipe(gulp.dest(paths.dist + '/assets/images/'));
});

gulp.task('fonts', function () {
  return gulp.src($.mainBowerFiles())
    .pipe($.filter('**/*.{eot,svg,ttf,woff}'))
    .pipe($.flatten())
    .pipe(gulp.dest(paths.dist + '/fonts/'));
});

gulp.task('misc', function () {
  return gulp.src(paths.src + '/**/*.ico')
    .pipe(gulp.dest(paths.dist + '/'));
});

gulp.task('clean', function (done) {
  $.del([paths.dist + '/', paths.tmp + '/'], done);
});

gulp.task('build', ['html', 'images', 'fonts', 'misc']);
EOF

# 15. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build --verbose

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

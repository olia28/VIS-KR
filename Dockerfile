# --- Етап 1: Збірка (Node 10 - Buster) ---
FROM node:10-buster AS build

WORKDIR /app

# 1. Фікс репозиторіїв Debian
RUN echo "deb http://archive.debian.org/debian/ buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security/ buster/updates main" >> /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update

# 2. Системні бібліотеки (мінімальний набір)
RUN apt-get install -y git python make g++

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

# 8. === ГОЛОВНА ЗМІНА: ПЕРЕХІД НА DART SASS ===
# Ми видаляємо node-sass (C++), який постійно падає.
# Ми ставимо sass (JS), який стабільний як скеля.
# gulp-sass версії 4.1.0 вміє працювати з новим sass.
RUN npm uninstall gulp-sass node-sass --unsafe-perm && \
    npm install gulp-sass@4.1.0 sass --save-dev --unsafe-perm

# 9. Gulp 3 Fix
RUN npm install graceful-fs@4 --save-dev --save-exact

# 10. Bower Fix
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.7.5" }, "dependencies": {/' bower.json

# 11. Bower Install
RUN bower install --allow-root --force

# 12. Копіюємо весь код
COPY . .

# =================================================================
# 13. === ОНОВЛЕННЯ КОНФІГІВ GULP ===
# =================================================================

# --- 1. gulp/styles.js (Використовуємо JS компілятор) ---
RUN cat <<'EOF' > gulp/styles.js
'use strict';
var gulp = require('gulp');
var paths = gulp.paths;
var $ = require('gulp-load-plugins')();

// ПІДКЛЮЧАЄМО DART SASS (JAVASCRIPT)
var sass = require('gulp-sass');
sass.compiler = require('sass');

gulp.task('styles', function () {
  var sassOptions = { style: 'expanded' };

  var injectFiles = gulp.src([
    paths.src + '/{app,components}/**/*.scss',
    '!' + paths.src + '/app/index.scss',
    '!' + paths.src + '/app/vendor.scss'
  ], { read: false });

  var injectOptions = {
    transform: function(filePath) {
      filePath = filePath.replace(paths.src + '/app/', '');
      filePath = filePath.replace(paths.src + '/components/', '../components/');
      return '@import \'' + filePath + '\';';
    },
    starttag: '// injector',
    endtag: '// endinjector',
    addRootSlash: false
  };

  var indexFilter = $.filter('index.scss');

  return gulp.src([
    paths.src + '/app/index.scss',
    paths.src + '/app/vendor.scss'
  ])
    .pipe(indexFilter)
    .pipe($.inject(injectFiles, injectOptions))
    .pipe(sass(sassOptions).on('error', sass.logError)) 
    .pipe(gulp.dest(paths.tmp + '/serve/app/'));
});
EOF

# --- 2. gulp/inject.js (Без сортування) ---
RUN cat <<'EOF' > gulp/inject.js
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

# --- 3. gulp/build.js (Без мініфікації) ---
RUN cat <<'EOF' > gulp/build.js
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

# 14. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build --verbose

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

# --- Етап 1: Збірка (Node 14 - Bullseye) ---
# Ми беремо новішу версію Node, яка не падає з помилкою пам'яті.
FROM node:14-bullseye AS build

WORKDIR /app

# 1. Встановлюємо інструменти.
# Цього разу без зайвих бібліотек (libgifsicle), які викликали помилки.
# Тільки те, що треба для node-sass.
RUN apt-get update && apt-get install -y git python3 make g++

# 2. Налаштування Git
RUN git config --global url."https://".insteadOf git://

# 3. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 4. Копіюємо конфіги
COPY package*.json bower.json* .bowerrc* ./

# 5. === ПАТЧ ДЛЯ GULP 3 НА NODE 14 ===
# Gulp 3 не любить Node 14. Ми його "обманюємо", створюючи цей файл.
# Це вирішує проблему "ReferenceError: primordials is not defined".
RUN echo '{ "dependencies": { "graceful-fs": { "version": "4.2.11" } } }' > npm-shrinkwrap.json

# 6. Встановлюємо залежності
RUN npm install --unsafe-perm --ignore-scripts

# 7. SASS FIX
# Ставимо версію, яка сумісна з Node 14
RUN npm uninstall gulp-sass node-sass --unsafe-perm && \
    npm install node-sass@4.14.1 gulp-sass@4.0.2 --save-dev --unsafe-perm

# 8. Ребілд (критично для Node 14)
RUN npm rebuild --unsafe-perm

# 9. Bower Fix
RUN sed -i 's/"dependencies": {/"resolutions": { "angular": "1.7.5" }, "dependencies": {/' bower.json

# 10. Bower Install
RUN bower install --allow-root --force

# 11. Копіюємо весь код
COPY . .

# =================================================================
# 12. === СПРОЩЕННЯ ФАЙЛІВ ЗБІРКИ ===
# Ми перезаписуємо файли Gulp "безпечними" версіями.
# Це прибирає Uglify, CSSO і сортування, які викликають збої.
# =================================================================

# --- 1. gulp/styles.js (Sass без наворотів) ---
RUN cat <<'EOF' > gulp/styles.js
'use strict';
var gulp = require('gulp');
var paths = gulp.paths;
var $ = require('gulp-load-plugins')();

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
    .pipe($.sass(sassOptions))
    .on('error', function handleError(err) {
      console.error(err.toString());
      this.emit('end');
    })
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

# --- 3. gulp/build.js (Тільки склеювання) ---
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

# 13. Запускаємо збірку
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build --verbose

# --- Етап 2: NGINX ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

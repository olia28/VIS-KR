# Використовуємо стабільну Node 14 (Bullseye)
FROM node:14-bullseye AS build

WORKDIR /app

# 1. Системні інструменти
RUN apt-get update && apt-get install -y git python3 make g++

# 2. Глобальні інструменти
RUN npm install -g gulp-cli bower

# 3. Копіюємо package.json (який ви щойно оновили)
COPY package*.json ./

# 4. Встановлюємо залежності
# legacy-peer-deps допомагає старим пакетам дружити з Node 14
RUN npm install --legacy-peer-deps

# 5. Копіюємо решту файлів
COPY . .

# 6. === ПЕРЕЗАПИСУЄМО ФАЙЛИ ЗБІРКИ ===
# Оскільки ми змінили бібліотеки, нам треба трохи підправити код Gulp,
# щоб він не шукав старі інструменти.
# ====================================

# Оновлюємо стилі під новий Sass
RUN cat <<'EOF' > gulp/styles.js
'use strict';
var gulp = require('gulp');
var paths = gulp.paths;
var $ = require('gulp-load-plugins')();
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

  return gulp.src([
    paths.src + '/app/index.scss',
    paths.src + '/app/vendor.scss'
  ])
    .pipe($.filter('index.scss'))
    .pipe($.inject(injectFiles, injectOptions))
    .pipe(sass(sassOptions).on('error', sass.logError))
    .pipe(gulp.dest(paths.tmp + '/serve/app/'));
});
EOF

# Оновлюємо Inject (прибираємо сортування)
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

  var wiredepOptions = { directory: 'bower_components' };

  return gulp.src(paths.src + '/*.html')
    .pipe($.inject(injectStyles, injectOptions))
    .pipe($.inject(injectScripts, injectOptions))
    .pipe(wiredep(wiredepOptions))
    .pipe(gulp.dest(paths.tmp + '/serve'));
});
EOF

# Оновлюємо Build (прибираємо мініфікацію)
RUN cat <<'EOF' > gulp/build.js
'use strict';
var gulp = require('gulp');
var paths = gulp.paths;
var $ = require('gulp-load-plugins')({
  pattern: ['gulp-*', 'main-bower-files', 'del']
});

gulp.task('partials', function () {
  return gulp.src([
    paths.src + '/{app,components}/**/*.html',
    paths.tmp + '/{app,components}/**/*.html'
  ])
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
    .pipe(gulp.dest(paths.dist + '/'));
});

gulp.task('images', function () {
  return gulp.src(paths.src + '/assets/images/**/*')
    .pipe(gulp.dest(paths.dist + '/assets/images/'));
});

gulp.task('fonts', function () {
  return gulp.src($.mainBowerFiles())
    .pipe($.filter('**/*.{eot,svg,ttf,woff}'))
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

# 7. Встановлюємо Bower і збираємо
RUN bower install --allow-root --force
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN gulp build --verbose

# Етап 2: NGINX
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

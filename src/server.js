require('dotenv').config();
const path = require('path');
const express = require('express');
const session = require('express-session');
const cookieParser = require('cookie-parser');
const flash = require('connect-flash');
const expressLayouts = require('express-ejs-layouts');

const { attachUser } = require('./middleware/auth');

const indexRouter = require('./routes/index');
const authRouter = require('./routes/auth');
const plansRouter = require('./routes/plans');
const teachersRouter = require('./routes/teachers');
const dashboardRouter = require('./routes/dashboard');

const app = express();
const PORT = process.env.PORT || 3000;

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(expressLayouts);
app.set('layout', 'layout');

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(cookieParser());
app.use(
  session({
    secret: process.env.SESSION_SECRET || 'ieum-hakseup-dev-secret',
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 1000 * 60 * 60 * 24 * 7 },
  })
);
app.use(flash());

app.use(express.static(path.join(__dirname, '..', 'public')));

app.use(attachUser);

app.use((req, res, next) => {
  res.locals.flashSuccess = req.flash('success');
  res.locals.flashError = req.flash('error');
  res.locals.currentPath = req.path;
  next();
});

app.use('/', indexRouter);
app.use('/', authRouter);
app.use('/plans', plansRouter);
app.use('/teachers', teachersRouter);
app.use('/dashboard', dashboardRouter);

app.use((req, res) => {
  res.status(404).render('404', { title: '페이지를 찾을 수 없어요' });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`이음학습 서버가 http://localhost:${PORT} 에서 실행 중입니다.`);
  });
}

module.exports = app;

const express = require('express');
const bcrypt = require('bcryptjs');
const { findUserByEmail, createUser, ensureDemoAccount } = require('../data/store');

const router = express.Router();

router.get('/signup', (req, res) => {
  res.render('auth/signup', { title: '회원가입', formData: {} });
});

router.post('/signup', (req, res) => {
  const { name, email, password, phone, accountType, relationship, learnerName, learnerAge } = req.body;

  if (!name || !email || !password) {
    req.flash('error', '이름, 이메일, 비밀번호는 꼭 입력해주세요.');
    return res.redirect('/signup');
  }

  if (findUserByEmail(email)) {
    req.flash('error', '이미 가입된 이메일이에요. 로그인해주세요.');
    return res.redirect('/login');
  }

  const passwordHash = bcrypt.hashSync(password, 10);
  const user = createUser({
    name,
    email,
    passwordHash,
    phone: phone || '',
    accountType: accountType === '시니어 본인' ? '시니어 본인' : '가족',
    relationship: relationship || '',
    learnerName: learnerName || '',
    learnerAge: learnerAge ? Number(learnerAge) : null,
  });

  req.session.userId = user.id;
  req.flash('success', `${name}님, 이음학습 가입을 환영합니다!`);
  res.redirect('/dashboard');
});

router.get('/login', (req, res) => {
  res.render('auth/login', { title: '로그인', next: req.query.next || '' });
});

router.post('/login', (req, res) => {
  const { email, password, next } = req.body;
  const user = findUserByEmail(email || '');

  if (!user || !user.passwordHash || !bcrypt.compareSync(password || '', user.passwordHash)) {
    req.flash('error', '이메일 또는 비밀번호가 올바르지 않아요.');
    return res.redirect('/login');
  }

  req.session.userId = user.id;
  req.flash('success', `다시 오셨군요, ${user.name}님!`);
  res.redirect(next && next.startsWith('/') ? next : '/dashboard');
});

// 체험 계정으로 바로 둘러보기 (데모)
router.post('/demo-login', (req, res) => {
  const demoUser = ensureDemoAccount();
  req.session.userId = demoUser.id;
  req.flash('success', '체험 계정으로 접속했어요. 마음껏 둘러보세요!');
  res.redirect('/dashboard');
});

router.post('/logout', (req, res) => {
  req.session.destroy(() => {
    res.redirect('/');
  });
});

module.exports = router;

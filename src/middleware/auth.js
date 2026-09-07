const { findUserById } = require('../data/store');

// 모든 요청에 로그인 사용자 정보를 뷰에서 쓸 수 있도록 주입
function attachUser(req, res, next) {
  if (req.session && req.session.userId) {
    const user = findUserById(req.session.userId);
    req.user = user || null;
  } else {
    req.user = null;
  }
  res.locals.currentUser = req.user;
  next();
}

// 로그인이 필요한 라우트 보호
function requireLogin(req, res, next) {
  if (!req.user) {
    req.flash('error', '로그인이 필요한 서비스예요.');
    return res.redirect('/login?next=' + encodeURIComponent(req.originalUrl));
  }
  next();
}

module.exports = { attachUser, requireLogin };

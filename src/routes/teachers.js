const express = require('express');
const { getTeachers, getTeacherById, createMatchRequest, getMatchRequestsByUser } = require('../data/store');
const { requireLogin } = require('../middleware/auth');

const router = express.Router();

router.get('/', (req, res) => {
  const teachers = getTeachers();
  const myRequests = req.user ? getMatchRequestsByUser(req.user.id) : [];
  const requestedTeacherIds = myRequests.map((m) => m.teacherId);
  res.render('teachers/index', { title: '방문 선생님 매칭', teachers, requestedTeacherIds });
});

router.post('/:id/request', requireLogin, (req, res) => {
  const teacher = getTeacherById(req.params.id);
  if (!teacher) {
    req.flash('error', '존재하지 않는 선생님이에요.');
    return res.redirect('/teachers');
  }
  const { message, preferredTime, serviceMode } = req.body;
  createMatchRequest(req.user.id, {
    teacherId: teacher.id,
    message: message || '',
    preferredTime: preferredTime || '',
    serviceMode: serviceMode === '센터 학습' ? '센터 학습' : '방문 학습',
  });
  req.flash('success', `${teacher.name}께 매칭 신청을 보냈어요. 확인 후 연락드릴게요.`);
  res.redirect('/dashboard');
});

module.exports = router;

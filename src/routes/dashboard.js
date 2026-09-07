const express = require('express');
const {
  getEnrollmentsByUser,
  getPlanById,
  getMatchRequestsByUser,
  getTeacherById,
  getVisitsByUser,
  getCareReportsByUser,
  ensureDemoAccount,
} = require('../data/store');
const { requireLogin } = require('../middleware/auth');

const router = express.Router();

router.get('/', requireLogin, (req, res) => {
  if (req.user.email === 'demo@ieum-hakseup.kr') ensureDemoAccount();
  const enrollments = getEnrollmentsByUser(req.user.id).map((e) => ({
    ...e,
    plan: getPlanById(e.planId),
  }));

  const matchRequests = getMatchRequestsByUser(req.user.id).map((m) => ({
    ...m,
    teacher: getTeacherById(m.teacherId),
  }));

  const allProgress = enrollments
    .flatMap((e) => e.progress.map((p) => ({ ...p, planTitle: e.plan ? e.plan.title : '학습지' })))
    .sort((a, b) => new Date(b.date) - new Date(a.date));

  const visits = getVisitsByUser(req.user.id)
    .map((visit) => ({ ...visit, teacher: getTeacherById(visit.teacherId) }))
    .sort((a, b) => new Date(b.scheduledAt) - new Date(a.scheduledAt));
  const careReports = getCareReportsByUser(req.user.id)
    .map((report) => ({ ...report, teacher: getTeacherById(report.teacherId) }))
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  res.render('dashboard/index', {
    title: '학습 현황 대시보드',
    enrollments,
    matchRequests,
    allProgress,
    visits,
    latestReport: careReports[0] || null,
  });
});

module.exports = router;

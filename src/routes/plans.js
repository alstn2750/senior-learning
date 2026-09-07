const express = require('express');
const { getPlans, getPlanById, createEnrollment, getEnrollmentsByUser } = require('../data/store');
const { requireLogin } = require('../middleware/auth');

const router = express.Router();

router.get('/', (req, res) => {
  const plans = getPlans();
  const myPlanIds = req.user ? getEnrollmentsByUser(req.user.id).map((e) => e.planId) : [];
  res.render('plans/index', { title: '배움 프로그램', plans, myPlanIds });
});

router.get('/:id', (req, res) => {
  const plan = getPlanById(req.params.id);
  if (!plan) {
    req.flash('error', '존재하지 않는 프로그램이에요.');
    return res.redirect('/plans');
  }
  const myPlanIds = req.user ? getEnrollmentsByUser(req.user.id).map((e) => e.planId) : [];
  res.render('plans/show', { title: plan.title, plan, alreadyEnrolled: myPlanIds.includes(plan.id) });
});

router.post('/:id/enroll', requireLogin, (req, res) => {
  const plan = getPlanById(req.params.id);
  if (!plan) {
    req.flash('error', '존재하지 않는 프로그램이에요.');
    return res.redirect('/plans');
  }
  const already = getEnrollmentsByUser(req.user.id).some((e) => e.planId === plan.id);
  if (already) {
    req.flash('success', '이미 이용 중인 프로그램이에요.');
    return res.redirect('/dashboard');
  }
  let serviceMode = ['방문 학습', '센터 학습'].includes(req.body.serviceMode)
    ? req.body.serviceMode
    : '방문 학습';
  if (plan.id === 'plan-hobby') serviceMode = '센터 학습';
  const weeklyFrequency = [1, 2, 3].includes(Number(req.body.weeklyFrequency))
    ? Number(req.body.weeklyFrequency)
    : 1;
  const payer = ['본인', '자녀'].includes(req.body.payer) ? req.body.payer : '자녀';
  createEnrollment(req.user.id, plan.id, { serviceMode, weeklyFrequency, payer });
  req.flash('success', `${plan.title} ${serviceMode}을 주 ${weeklyFrequency}회로 신청했어요!`);
  res.redirect('/dashboard');
});

module.exports = router;

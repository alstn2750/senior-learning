const express = require('express');
const { getPlans, getTeachers } = require('../data/store');

const router = express.Router();

router.get('/', (req, res) => {
  const plans = getPlans().slice(0, 3);
  const teachers = getTeachers().slice(0, 3);
  res.render('index', { title: '이음학습 - 배움으로 잇는 예방적 돌봄', plans, teachers });
});

module.exports = router;

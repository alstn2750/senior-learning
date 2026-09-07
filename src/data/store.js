const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const SEED_DIR = path.join(__dirname, 'seed');
const RUNTIME_DIR = path.join(__dirname, 'runtime');

if (!fs.existsSync(RUNTIME_DIR)) {
  fs.mkdirSync(RUNTIME_DIR, { recursive: true });
}

function seedPath(name) {
  return path.join(SEED_DIR, `${name}.json`);
}

function runtimePath(name) {
  return path.join(RUNTIME_DIR, `${name}.json`);
}

function readJson(filePath, fallback) {
  try {
    const raw = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') return fallback;
    throw err;
  }
}

function writeJson(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8');
}

// 읽기 전용 시드 데이터 (구독 상품, 선생님 목록)
function getPlans() {
  return readJson(seedPath('plans'), []);
}

function getPlanById(id) {
  return getPlans().find((p) => p.id === id) || null;
}

function getTeachers() {
  return readJson(seedPath('teachers'), []);
}

function getTeacherById(id) {
  return getTeachers().find((t) => t.id === id) || null;
}

// 런타임 데이터 (회원가입 시 생성, 서버 재시작 시 초기화되지 않고 파일에 유지되는 임시 저장소)
function getCollection(name) {
  return readJson(runtimePath(name), []);
}

function saveCollection(name, data) {
  writeJson(runtimePath(name), data);
}

function generateId(prefix) {
  return `${prefix}-${crypto.randomBytes(4).toString('hex')}`;
}

// --- 사용자 ---
function findUserByEmail(email) {
  const users = getCollection('users');
  return users.find((u) => u.email.toLowerCase() === email.toLowerCase()) || null;
}

function findUserById(id) {
  const users = getCollection('users');
  return users.find((u) => u.id === id) || null;
}

function createUser(user) {
  const users = getCollection('users');
  const newUser = {
    id: generateId('user'),
    createdAt: new Date().toISOString(),
    ...user,
  };
  users.push(newUser);
  saveCollection('users', users);
  return newUser;
}

// --- 구독 신청 (학습지 구독) ---
function getEnrollmentsByUser(userId) {
  return getCollection('enrollments').filter((e) => e.userId === userId);
}

function createEnrollment(userId, planId, options = {}) {
  const enrollments = getCollection('enrollments');
  const enrollment = {
    id: generateId('enr'),
    userId,
    planId,
    status: '진행중',
    startDate: new Date().toISOString(),
    serviceMode: options.serviceMode || '방문 학습',
    weeklyFrequency: Number(options.weeklyFrequency) || 1,
    payer: options.payer || '자녀',
    progress: [],
  };
  enrollments.push(enrollment);
  saveCollection('enrollments', enrollments);
  return enrollment;
}

// --- 수업 안전 여정과 가족 안부 리포트 ---
function getVisitsByUser(userId) {
  return getCollection('visits').filter((visit) => visit.userId === userId);
}

function getCareReportsByUser(userId) {
  return getCollection('careReports').filter((report) => report.userId === userId);
}

// --- 방문 선생님 매칭 신청 ---
function getMatchRequestsByUser(userId) {
  return getCollection('matchRequests').filter((m) => m.userId === userId);
}

function createMatchRequest(userId, data) {
  const matchRequests = getCollection('matchRequests');
  const request = {
    id: generateId('match'),
    userId,
    status: '신청 접수',
    createdAt: new Date().toISOString(),
    ...data,
  };
  matchRequests.push(request);
  saveCollection('matchRequests', matchRequests);
  return request;
}

// --- 데모 체험 계정: 대시보드를 바로 볼 수 있도록 학습 기록이 채워진 샘플 데이터 보장 ---
function ensureDemoAccount() {
  const demoEmail = 'demo@ieum-hakseup.kr';
  let demoUser = findUserByEmail(demoEmail);
  if (!demoUser) {
    demoUser = createUser({
      name: '체험 계정',
      email: demoEmail,
      passwordHash: null,
      phone: '010-0000-0000',
      accountType: '가족',
      relationship: '자녀',
      learnerName: '김말순 어머니',
      learnerAge: 68,
    });
  }

  const plans = getPlans();
  const enrollments = getCollection('enrollments');
  const progressSamples = [
    { date: daysAgo(14), note: '받침 있는 글자 쓰기 연습을 시작했어요.', score: 72 },
    { date: daysAgo(7), note: '받아쓰기 10문제 중 8문제를 맞히셨어요.', score: 84 },
    { date: daysAgo(1), note: '짧은 일기 쓰기에 도전하셨어요. 표현력이 늘었습니다.', score: 90 },
  ];
  if (!enrollments.some((enrollment) => enrollment.userId === demoUser.id)) {
    enrollments.push({
      id: generateId('enr'),
      userId: demoUser.id,
      planId: plans[0] ? plans[0].id : 'plan-hangul',
      status: '진행중',
      startDate: daysAgo(20),
      serviceMode: '방문 학습',
      weeklyFrequency: 2,
      payer: '자녀',
      progress: progressSamples,
    });
    enrollments.push({
      id: generateId('enr'),
      userId: demoUser.id,
      planId: plans[2] ? plans[2].id : 'plan-brain',
      status: '진행중',
      startDate: daysAgo(10),
      serviceMode: '센터 학습',
      weeklyFrequency: 1,
      payer: '자녀',
      progress: [
        { date: daysAgo(5), note: '기억력 카드 맞추기 훈련, 집중력이 좋아지셨어요.', score: 78 },
        { date: daysAgo(2), note: '오늘의 두뇌 퀴즈 5문제 전부 맞히셨습니다!', score: 95 },
      ],
    });
    saveCollection('enrollments', enrollments);
  }

  const matchRequests = getCollection('matchRequests');
  if (!matchRequests.some((request) => request.userId === demoUser.id)) {
    matchRequests.push({
      id: generateId('match'),
      userId: demoUser.id,
      teacherId: 'teacher-01',
      message: '한글 쓰기 수업을 매주 화, 목요일 오전에 받고 싶어요.',
      preferredTime: '평일 오전',
      status: '매칭 완료',
      createdAt: daysAgo(20),
    });
    saveCollection('matchRequests', matchRequests);
  }

  const visits = getCollection('visits');
  if (!visits.some((visit) => visit.userId === demoUser.id)) {
    visits.push(
      {
        id: generateId('visit'),
        userId: demoUser.id,
        teacherId: 'teacher-01',
        scheduledAt: hoursFromNow(20),
        mode: '방문 학습',
        subject: '생활 한글과 디지털 기초',
        status: '방문 예정',
        safetySteps: [
          { label: '방문 일정 확정', state: 'done' },
          { label: 'NFC 도착 인증', state: 'upcoming' },
          { label: '수업 종료 알림', state: 'upcoming' },
          { label: '강사 귀가 확인', state: 'upcoming' },
        ],
      },
      {
        id: generateId('visit'),
        userId: demoUser.id,
        teacherId: 'teacher-01',
        scheduledAt: daysAgo(2),
        mode: '방문 학습',
        subject: '인지 카드와 일상 대화',
        status: '안전 종료',
        safetySteps: [
          { label: 'NFC 도착 인증', state: 'done' },
          { label: 'GPS 경로 공유', state: 'done' },
          { label: '수업 종료 알림', state: 'done' },
          { label: '강사 귀가 확인', state: 'done' },
        ],
      }
    );
    saveCollection('visits', visits);
  }

  const reports = getCollection('careReports');
  if (!reports.some((report) => report.userId === demoUser.id)) {
    reports.push({
      id: generateId('report'),
      userId: demoUser.id,
      teacherId: 'teacher-01',
      createdAt: daysAgo(2),
      mood: 5,
      energy: 4,
      focus: 5,
      note: '오늘은 손주 사진을 보여주시며 먼저 이야기를 꺼내셨어요. 인지 카드 활동도 끝까지 즐겁게 참여하셨습니다.',
      familyPrompt: '오늘 배운 사진 보내기를 함께 해보며 손주 이야기를 나눠보세요.',
    });
    saveCollection('careReports', reports);
  }

  return demoUser;
}

function hoursFromNow(n) {
  const date = new Date();
  date.setHours(date.getHours() + n);
  return date.toISOString();
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString();
}

module.exports = {
  getPlans,
  getPlanById,
  getTeachers,
  getTeacherById,
  findUserByEmail,
  findUserById,
  createUser,
  getEnrollmentsByUser,
  createEnrollment,
  getMatchRequestsByUser,
  createMatchRequest,
  getVisitsByUser,
  getCareReportsByUser,
  ensureDemoAccount,
};

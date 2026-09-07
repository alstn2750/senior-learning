-- 이음학습 MySQL 8.0 스키마
-- 문자 집합: utf8mb4 / 시간 저장: UTC 권장 (표시는 Asia/Seoul에서 변환)

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE DATABASE IF NOT EXISTS gumon
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE gumon;

-- 1. 계정과 학습자 ----------------------------------------------------------

CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '사용자 PK',
  email VARCHAR(255) NOT NULL COMMENT '로그인 이메일',
  password_hash VARCHAR(255) NULL COMMENT 'bcrypt 해시, 소셜/체험 계정은 NULL 가능',
  name VARCHAR(80) NOT NULL COMMENT '가입자 이름',
  phone VARCHAR(30) NULL COMMENT '연락처',
  account_type VARCHAR(20) NOT NULL DEFAULT 'FAMILY' COMMENT 'SENIOR/FAMILY/TEACHER/ADMIN',
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT 'PENDING/ACTIVE/SUSPENDED/WITHDRAWN',
  email_verified_at DATETIME(3) NULL,
  last_login_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email),
  KEY idx_users_status_created (status, created_at),
  CONSTRAINT chk_users_account_type CHECK (account_type IN ('SENIOR','FAMILY','TEACHER','ADMIN')),
  CONSTRAINT chk_users_status CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','WITHDRAWN'))
) ENGINE=InnoDB COMMENT='로그인 계정';

CREATE TABLE learners (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '학습자 PK',
  user_id BIGINT UNSIGNED NULL COMMENT '본인 가입 시 연결 계정',
  name VARCHAR(80) NOT NULL,
  birth_date DATE NULL COMMENT '연령 대신 생년월일 저장',
  phone VARCHAR(30) NULL,
  preferred_contact VARCHAR(20) NOT NULL DEFAULT 'GUARDIAN' COMMENT 'SELF/GUARDIAN',
  accessibility_notes VARCHAR(500) NULL COMMENT '큰 글씨 등 수업 편의 요청',
  emergency_contact_name VARCHAR(80) NULL,
  emergency_contact_phone VARCHAR(30) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_learners_user (user_id),
  CONSTRAINT fk_learners_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT chk_learners_contact CHECK (preferred_contact IN ('SELF','GUARDIAN')),
  CONSTRAINT chk_learners_status CHECK (status IN ('ACTIVE','INACTIVE'))
) ENGINE=InnoDB COMMENT='실제 수업을 받는 시니어';

CREATE TABLE learner_guardians (
  learner_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  relationship VARCHAR(30) NULL COMMENT '딸/아들/배우자 등',
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  can_view_reports TINYINT(1) NOT NULL DEFAULT 1,
  can_receive_safety_alerts TINYINT(1) NOT NULL DEFAULT 1,
  can_manage_enrollment TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (learner_id, user_id),
  KEY idx_guardians_user (user_id),
  CONSTRAINT fk_guardians_learner FOREIGN KEY (learner_id) REFERENCES learners(id) ON DELETE CASCADE,
  CONSTRAINT fk_guardians_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='학습자와 가족 계정의 다대다 연결 및 권한';

CREATE TABLE addresses (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  learner_id BIGINT UNSIGNED NOT NULL,
  label VARCHAR(40) NOT NULL DEFAULT '집',
  postal_code VARCHAR(10) NULL,
  address_line1 VARCHAR(255) NOT NULL,
  address_line2 VARCHAR(255) NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  access_notes VARCHAR(500) NULL COMMENT '공동현관 등 방문 안내',
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY idx_addresses_learner (learner_id, is_default),
  CONSTRAINT fk_addresses_learner FOREIGN KEY (learner_id) REFERENCES learners(id) ON DELETE CASCADE,
  CONSTRAINT chk_addresses_lat CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT chk_addresses_lng CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB COMMENT='방문 수업 주소';

CREATE TABLE user_consents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  learner_id BIGINT UNSIGNED NULL,
  learner_scope_id BIGINT UNSIGNED GENERATED ALWAYS AS (COALESCE(learner_id, 0)) STORED COMMENT 'NULL 범위 중복 방지용',
  consent_type VARCHAR(40) NOT NULL COMMENT 'TERMS/PRIVACY/LOCATION/REPORT_SHARE/MARKETING',
  policy_version VARCHAR(30) NOT NULL,
  is_agreed TINYINT(1) NOT NULL,
  agreed_at DATETIME(3) NULL,
  revoked_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_consents_scope (user_id, learner_scope_id, consent_type, policy_version),
  KEY idx_consents_learner (learner_id, consent_type),
  CONSTRAINT fk_consents_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_consents_learner FOREIGN KEY (learner_id) REFERENCES learners(id) ON DELETE CASCADE,
  CONSTRAINT chk_consents_type CHECK (consent_type IN ('TERMS','PRIVACY','LOCATION','REPORT_SHARE','MARKETING'))
) ENGINE=InnoDB COMMENT='약관과 위치·리포트 공유 동의 이력';

-- 2. 센터와 프로그램 --------------------------------------------------------

CREATE TABLE centers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  phone VARCHAR(30) NULL,
  postal_code VARCHAR(10) NULL,
  address_line1 VARCHAR(255) NOT NULL,
  address_line2 VARCHAR(255) NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  operating_hours JSON NULL COMMENT '요일별 운영시간',
  capacity SMALLINT UNSIGNED NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY idx_centers_status (status),
  CONSTRAINT chk_centers_status CHECK (status IN ('PREPARING','ACTIVE','INACTIVE'))
) ENGINE=InnoDB COMMENT='센터 수업 운영 장소';

CREATE TABLE nfc_tags (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tag_uid_hash CHAR(64) NOT NULL COMMENT 'NFC UID의 SHA-256 이상 해시',
  address_id BIGINT UNSIGNED NULL COMMENT '방문 수업 장소 태그',
  center_id BIGINT UNSIGNED NULL COMMENT '센터 출입 태그',
  label VARCHAR(80) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  activated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  revoked_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_nfc_tags_uid (tag_uid_hash),
  KEY idx_nfc_tags_address (address_id, status),
  KEY idx_nfc_tags_center (center_id, status),
  CONSTRAINT fk_nfc_tags_address FOREIGN KEY (address_id) REFERENCES addresses(id) ON DELETE CASCADE,
  CONSTRAINT fk_nfc_tags_center FOREIGN KEY (center_id) REFERENCES centers(id) ON DELETE CASCADE,
  CONSTRAINT chk_nfc_tags_owner CHECK ((address_id IS NOT NULL AND center_id IS NULL) OR (address_id IS NULL AND center_id IS NOT NULL)),
  CONSTRAINT chk_nfc_tags_status CHECK (status IN ('ACTIVE','REVOKED','LOST'))
) ENGINE=InnoDB COMMENT='도착 인증에 사용하는 등록 NFC 태그';

CREATE TABLE program_categories (
  id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(40) NOT NULL COMMENT 'DIGITAL/WELLNESS/COGNITIVE 등',
  name VARCHAR(80) NOT NULL,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uk_program_categories_code (code)
) ENGINE=InnoDB COMMENT='프로그램 분야';

CREATE TABLE programs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id SMALLINT UNSIGNED NOT NULL,
  slug VARCHAR(100) NOT NULL COMMENT 'URL용 식별자',
  title VARCHAR(150) NOT NULL,
  level VARCHAR(30) NOT NULL,
  summary VARCHAR(300) NOT NULL,
  description TEXT NOT NULL,
  icon VARCHAR(20) NULL,
  color_code VARCHAR(20) NULL,
  medical_disclaimer VARCHAR(500) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_programs_slug (slug),
  KEY idx_programs_category_status (category_id, status),
  CONSTRAINT fk_programs_category FOREIGN KEY (category_id) REFERENCES program_categories(id),
  CONSTRAINT chk_programs_status CHECK (status IN ('DRAFT','ACTIVE','PAUSED','ARCHIVED'))
) ENGINE=InnoDB COMMENT='배움 프로그램 상품';

CREATE TABLE program_recommendations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  program_id BIGINT UNSIGNED NOT NULL,
  content VARCHAR(300) NOT NULL,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_recommendations_program (program_id, sort_order),
  CONSTRAINT fk_recommendations_program FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='프로그램 추천 대상 문구';

CREATE TABLE program_curriculum (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  program_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL,
  description VARCHAR(500) NULL,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_curriculum_program (program_id, sort_order),
  CONSTRAINT fk_curriculum_program FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='프로그램 커리큘럼 항목';

CREATE TABLE program_price_options (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  program_id BIGINT UNSIGNED NOT NULL,
  service_mode VARCHAR(20) NOT NULL COMMENT 'HOME/CENTER',
  weekly_frequency TINYINT UNSIGNED NOT NULL,
  monthly_price DECIMAL(12,0) UNSIGNED NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'KRW',
  valid_from DATE NOT NULL,
  valid_to DATE NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_program_price (program_id, service_mode, weekly_frequency, valid_from),
  KEY idx_program_price_active (program_id, is_active, valid_from, valid_to),
  CONSTRAINT fk_program_price_program FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE,
  CONSTRAINT chk_program_price_mode CHECK (service_mode IN ('HOME','CENTER')),
  CONSTRAINT chk_program_price_frequency CHECK (weekly_frequency BETWEEN 1 AND 7)
) ENGINE=InnoDB COMMENT='방식·주간 횟수별 월 가격과 가격 이력';

-- 3. 선생님과 검증 ----------------------------------------------------------

CREATE TABLE teachers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NULL,
  display_name VARCHAR(80) NOT NULL,
  bio TEXT NULL,
  career_summary VARCHAR(200) NULL,
  career_years SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  rating DECIMAL(2,1) NOT NULL DEFAULT 0.0,
  review_count INT UNSIGNED NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  hired_at DATE NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_teachers_user (user_id),
  KEY idx_teachers_status_rating (status, rating),
  CONSTRAINT fk_teachers_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT chk_teachers_rating CHECK (rating BETWEEN 0 AND 5),
  CONSTRAINT chk_teachers_status CHECK (status IN ('PENDING','ACTIVE','PAUSED','REJECTED','WITHDRAWN'))
) ENGINE=InnoDB COMMENT='선생님 프로필';

CREATE TABLE teacher_specialties (
  teacher_id BIGINT UNSIGNED NOT NULL,
  category_id SMALLINT UNSIGNED NOT NULL,
  years_experience SMALLINT UNSIGNED NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (teacher_id, category_id),
  CONSTRAINT fk_specialties_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id) ON DELETE CASCADE,
  CONSTRAINT fk_specialties_category FOREIGN KEY (category_id) REFERENCES program_categories(id)
) ENGINE=InnoDB COMMENT='선생님 전문 분야';

CREATE TABLE teacher_verifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  teacher_id BIGINT UNSIGNED NOT NULL,
  verification_type VARCHAR(30) NOT NULL COMMENT 'IDENTITY/CAREER/CERTIFICATE/SAFETY/COMMUNICATION',
  title VARCHAR(120) NOT NULL,
  issuer VARCHAR(120) NULL,
  reference_no VARCHAR(120) NULL COMMENT '민감값은 암호화 또는 마스킹',
  verified_at DATETIME(3) NULL,
  expires_at DATETIME(3) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  reviewer_user_id BIGINT UNSIGNED NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_verifications_teacher (teacher_id, status, expires_at),
  CONSTRAINT fk_verifications_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id) ON DELETE CASCADE,
  CONSTRAINT fk_verifications_reviewer FOREIGN KEY (reviewer_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT chk_verifications_type CHECK (verification_type IN ('IDENTITY','CAREER','CERTIFICATE','SAFETY','EMERGENCY','COMMUNICATION')),
  CONSTRAINT chk_verifications_status CHECK (status IN ('PENDING','VERIFIED','REJECTED','EXPIRED'))
) ENGINE=InnoDB COMMENT='신원·경력·자격·교육 검증 이력';

CREATE TABLE teacher_service_areas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  teacher_id BIGINT UNSIGNED NOT NULL,
  sido VARCHAR(40) NOT NULL,
  sigungu VARCHAR(60) NULL,
  eupmyeondong VARCHAR(60) NULL,
  service_mode VARCHAR(20) NOT NULL,
  center_id BIGINT UNSIGNED NULL,
  travel_radius_km DECIMAL(5,2) NULL,
  PRIMARY KEY (id),
  KEY idx_service_areas_region (sido, sigungu, service_mode),
  KEY idx_service_areas_teacher (teacher_id),
  CONSTRAINT fk_service_areas_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id) ON DELETE CASCADE,
  CONSTRAINT fk_service_areas_center FOREIGN KEY (center_id) REFERENCES centers(id) ON DELETE CASCADE,
  CONSTRAINT chk_service_areas_mode CHECK (service_mode IN ('HOME','CENTER')),
  CONSTRAINT chk_service_areas_center CHECK ((service_mode = 'HOME') OR (center_id IS NOT NULL))
) ENGINE=InnoDB COMMENT='선생님 방문 지역 및 소속 센터';

CREATE TABLE teacher_availability (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  teacher_id BIGINT UNSIGNED NOT NULL,
  day_of_week TINYINT UNSIGNED NOT NULL COMMENT '1=월요일, 7=일요일',
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  service_mode VARCHAR(20) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_availability_match (day_of_week, start_time, end_time, service_mode, is_active),
  KEY idx_availability_teacher (teacher_id),
  CONSTRAINT fk_availability_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id) ON DELETE CASCADE,
  CONSTRAINT chk_availability_day CHECK (day_of_week BETWEEN 1 AND 7),
  CONSTRAINT chk_availability_time CHECK (start_time < end_time),
  CONSTRAINT chk_availability_mode CHECK (service_mode IN ('HOME','CENTER'))
) ENGINE=InnoDB COMMENT='선생님 정기 가능 시간';

-- 4. 신청, 매칭, 수업 -------------------------------------------------------

CREATE TABLE enrollments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  learner_id BIGINT UNSIGNED NOT NULL,
  program_id BIGINT UNSIGNED NOT NULL,
  price_option_id BIGINT UNSIGNED NOT NULL,
  purchaser_user_id BIGINT UNSIGNED NOT NULL,
  payer_type VARCHAR(20) NOT NULL COMMENT 'SELF/FAMILY/ORGANIZATION/VOUCHER',
  service_mode VARCHAR(20) NOT NULL,
  weekly_frequency TINYINT UNSIGNED NOT NULL,
  monthly_price DECIMAL(12,0) UNSIGNED NOT NULL COMMENT '신청 당시 금액 스냅샷',
  preferred_schedule VARCHAR(300) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  start_date DATE NULL,
  end_date DATE NULL,
  cancelled_at DATETIME(3) NULL,
  cancellation_reason VARCHAR(500) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_enrollments_learner_status (learner_id, status),
  KEY idx_enrollments_program_status (program_id, status),
  KEY idx_enrollments_purchaser (purchaser_user_id, created_at),
  CONSTRAINT fk_enrollments_learner FOREIGN KEY (learner_id) REFERENCES learners(id),
  CONSTRAINT fk_enrollments_program FOREIGN KEY (program_id) REFERENCES programs(id),
  CONSTRAINT fk_enrollments_price FOREIGN KEY (price_option_id) REFERENCES program_price_options(id),
  CONSTRAINT fk_enrollments_purchaser FOREIGN KEY (purchaser_user_id) REFERENCES users(id),
  CONSTRAINT chk_enrollments_payer CHECK (payer_type IN ('SELF','FAMILY','ORGANIZATION','VOUCHER')),
  CONSTRAINT chk_enrollments_mode CHECK (service_mode IN ('HOME','CENTER')),
  CONSTRAINT chk_enrollments_frequency CHECK (weekly_frequency BETWEEN 1 AND 7),
  CONSTRAINT chk_enrollments_status CHECK (status IN ('PENDING','ACTIVE','PAUSED','COMPLETED','CANCELLED'))
) ENGINE=InnoDB COMMENT='프로그램 이용 신청/구독';

CREATE TABLE teacher_match_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  enrollment_id BIGINT UNSIGNED NOT NULL,
  requested_teacher_id BIGINT UNSIGNED NULL COMMENT '지정하지 않으면 운영자 추천',
  assigned_teacher_id BIGINT UNSIGNED NULL,
  requested_by_user_id BIGINT UNSIGNED NOT NULL,
  preferred_time VARCHAR(200) NULL,
  message VARCHAR(1000) NULL,
  service_mode VARCHAR(20) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'RECEIVED',
  responded_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_match_enrollment (enrollment_id, status),
  KEY idx_match_requested_teacher (requested_teacher_id, status),
  KEY idx_match_assigned_teacher (assigned_teacher_id, status),
  CONSTRAINT fk_match_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE,
  CONSTRAINT fk_match_requested_teacher FOREIGN KEY (requested_teacher_id) REFERENCES teachers(id) ON DELETE SET NULL,
  CONSTRAINT fk_match_assigned_teacher FOREIGN KEY (assigned_teacher_id) REFERENCES teachers(id) ON DELETE SET NULL,
  CONSTRAINT fk_match_requester FOREIGN KEY (requested_by_user_id) REFERENCES users(id),
  CONSTRAINT chk_match_mode CHECK (service_mode IN ('HOME','CENTER')),
  CONSTRAINT chk_match_status CHECK (status IN ('RECEIVED','REVIEWING','OFFERED','MATCHED','DECLINED','CANCELLED'))
) ENGINE=InnoDB COMMENT='선생님 매칭 요청과 배정';

CREATE TABLE class_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  enrollment_id BIGINT UNSIGNED NOT NULL,
  teacher_id BIGINT UNSIGNED NOT NULL,
  learner_id BIGINT UNSIGNED NOT NULL,
  center_id BIGINT UNSIGNED NULL,
  address_id BIGINT UNSIGNED NULL,
  service_mode VARCHAR(20) NOT NULL,
  subject VARCHAR(200) NOT NULL,
  scheduled_start_at DATETIME(3) NOT NULL,
  scheduled_end_at DATETIME(3) NOT NULL,
  actual_start_at DATETIME(3) NULL,
  actual_end_at DATETIME(3) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
  cancelled_by_user_id BIGINT UNSIGNED NULL,
  cancellation_reason VARCHAR(500) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_sessions_learner_schedule (learner_id, scheduled_start_at),
  KEY idx_sessions_teacher_schedule (teacher_id, scheduled_start_at),
  KEY idx_sessions_status_schedule (status, scheduled_start_at),
  CONSTRAINT fk_class_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id),
  CONSTRAINT fk_class_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id),
  CONSTRAINT fk_class_learner FOREIGN KEY (learner_id) REFERENCES learners(id),
  CONSTRAINT fk_class_center FOREIGN KEY (center_id) REFERENCES centers(id) ON DELETE SET NULL,
  CONSTRAINT fk_class_address FOREIGN KEY (address_id) REFERENCES addresses(id) ON DELETE SET NULL,
  CONSTRAINT fk_class_cancel_user FOREIGN KEY (cancelled_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT chk_class_time CHECK (scheduled_start_at < scheduled_end_at),
  CONSTRAINT chk_class_mode CHECK (service_mode IN ('HOME','CENTER')),
  CONSTRAINT chk_class_location CHECK ((service_mode = 'HOME' AND address_id IS NOT NULL) OR (service_mode = 'CENTER' AND center_id IS NOT NULL)),
  CONSTRAINT chk_class_status CHECK (status IN ('SCHEDULED','TEACHER_EN_ROUTE','ARRIVED','IN_PROGRESS','COMPLETED','CANCELLED','NO_SHOW'))
) ENGINE=InnoDB COMMENT='회차별 실제 수업 일정';

CREATE TABLE teacher_reviews (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  class_session_id BIGINT UNSIGNED NOT NULL,
  teacher_id BIGINT UNSIGNED NOT NULL,
  author_user_id BIGINT UNSIGNED NOT NULL,
  rating TINYINT UNSIGNED NOT NULL,
  content VARCHAR(2000) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PUBLISHED',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_teacher_reviews_session_author (class_session_id, author_user_id),
  KEY idx_teacher_reviews_teacher (teacher_id, status, created_at),
  CONSTRAINT fk_reviews_class FOREIGN KEY (class_session_id) REFERENCES class_sessions(id),
  CONSTRAINT fk_reviews_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id),
  CONSTRAINT fk_reviews_author FOREIGN KEY (author_user_id) REFERENCES users(id),
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT chk_reviews_status CHECK (status IN ('PUBLISHED','HIDDEN','REPORTED'))
) ENGINE=InnoDB COMMENT='완료 수업에 대한 선생님 후기';

CREATE TABLE session_safety_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  class_session_id BIGINT UNSIGNED NOT NULL,
  event_type VARCHAR(30) NOT NULL COMMENT 'SCHEDULE_CONFIRMED/NFC_ARRIVAL/GPS_SHARED/CLASS_STARTED/CLASS_ENDED/TEACHER_RETURNED',
  event_status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
  actor_user_id BIGINT UNSIGNED NULL,
  occurred_at DATETIME(3) NOT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  nfc_token_hash CHAR(64) NULL COMMENT '원문 NFC 토큰은 저장하지 않음',
  metadata JSON NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_safety_event_once (class_session_id, event_type),
  KEY idx_safety_occurred (occurred_at),
  CONSTRAINT fk_safety_session FOREIGN KEY (class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE,
  CONSTRAINT fk_safety_actor FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT chk_safety_type CHECK (event_type IN ('SCHEDULE_CONFIRMED','TEACHER_DEPARTED','NFC_ARRIVAL','GPS_SHARED','CLASS_STARTED','CLASS_ENDED','TEACHER_RETURNED','EMERGENCY')),
  CONSTRAINT chk_safety_status CHECK (event_status IN ('COMPLETED','FAILED','CANCELLED')),
  CONSTRAINT chk_safety_lat CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT chk_safety_lng CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB COMMENT='NFC·도착·종료·귀가 등 변경 불가형 안전 이벤트';

CREATE TABLE location_share_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  class_session_id BIGINT UNSIGNED NOT NULL,
  teacher_id BIGINT UNSIGNED NOT NULL,
  consent_id BIGINT UNSIGNED NOT NULL,
  share_token_hash CHAR(64) NOT NULL,
  started_at DATETIME(3) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  ended_at DATETIME(3) NULL,
  last_latitude DECIMAL(10,7) NULL,
  last_longitude DECIMAL(10,7) NULL,
  last_location_at DATETIME(3) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_location_token (share_token_hash),
  KEY idx_location_session_status (class_session_id, status),
  KEY idx_location_expiry (status, expires_at),
  CONSTRAINT fk_location_class FOREIGN KEY (class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE,
  CONSTRAINT fk_location_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id),
  CONSTRAINT fk_location_consent FOREIGN KEY (consent_id) REFERENCES user_consents(id),
  CONSTRAINT chk_location_period CHECK (started_at < expires_at),
  CONSTRAINT chk_location_status CHECK (status IN ('ACTIVE','ENDED','EXPIRED','REVOKED'))
) ENGINE=InnoDB COMMENT='방문 시간에 한정된 GPS 공유 세션(전체 이동경로는 기본 미보관)';

-- 5. 학습 기록과 가족 안부 --------------------------------------------------

CREATE TABLE learning_records (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  class_session_id BIGINT UNSIGNED NOT NULL,
  enrollment_id BIGINT UNSIGNED NOT NULL,
  learner_id BIGINT UNSIGNED NOT NULL,
  teacher_id BIGINT UNSIGNED NOT NULL,
  participation_score TINYINT UNSIGNED NULL COMMENT '프로토타입 호환 0~100 참여 지표',
  activity_title VARCHAR(200) NOT NULL,
  note TEXT NULL,
  next_activity VARCHAR(500) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_learning_session (class_session_id),
  KEY idx_learning_learner_created (learner_id, created_at),
  CONSTRAINT fk_learning_class FOREIGN KEY (class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE,
  CONSTRAINT fk_learning_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id),
  CONSTRAINT fk_learning_learner FOREIGN KEY (learner_id) REFERENCES learners(id),
  CONSTRAINT fk_learning_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id),
  CONSTRAINT chk_learning_score CHECK (participation_score IS NULL OR participation_score BETWEEN 0 AND 100)
) ENGINE=InnoDB COMMENT='수업별 학습 활동과 참여 기록';

CREATE TABLE care_reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  class_session_id BIGINT UNSIGNED NOT NULL,
  learner_id BIGINT UNSIGNED NOT NULL,
  teacher_id BIGINT UNSIGNED NOT NULL,
  mood_score TINYINT UNSIGNED NOT NULL,
  energy_score TINYINT UNSIGNED NOT NULL,
  focus_score TINYINT UNSIGNED NOT NULL,
  observation_note TEXT NOT NULL COMMENT '진단이 아닌 수업 중 관찰',
  family_prompt VARCHAR(500) NULL,
  published_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_care_report_session (class_session_id),
  KEY idx_care_learner_published (learner_id, published_at),
  CONSTRAINT fk_care_class FOREIGN KEY (class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE,
  CONSTRAINT fk_care_learner FOREIGN KEY (learner_id) REFERENCES learners(id),
  CONSTRAINT fk_care_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id),
  CONSTRAINT chk_care_mood CHECK (mood_score BETWEEN 1 AND 5),
  CONSTRAINT chk_care_energy CHECK (energy_score BETWEEN 1 AND 5),
  CONSTRAINT chk_care_focus CHECK (focus_score BETWEEN 1 AND 5)
) ENGINE=InnoDB COMMENT='수업 후 기분·활력·집중도와 가족 대화 리포트';

CREATE TABLE notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  class_session_id BIGINT UNSIGNED NULL,
  notification_type VARCHAR(40) NOT NULL COMMENT '수업 예정/도착/종료/리포트/결제 등',
  channel VARCHAR(20) NOT NULL,
  title VARCHAR(150) NOT NULL,
  body VARCHAR(1000) NOT NULL,
  payload JSON NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  scheduled_at DATETIME(3) NULL,
  sent_at DATETIME(3) NULL,
  read_at DATETIME(3) NULL,
  failure_reason VARCHAR(500) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_notifications_delivery (status, scheduled_at),
  KEY idx_notifications_user (user_id, read_at, created_at),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_notifications_class FOREIGN KEY (class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE,
  CONSTRAINT chk_notifications_channel CHECK (channel IN ('IN_APP','SMS','PUSH','EMAIL')),
  CONSTRAINT chk_notifications_status CHECK (status IN ('PENDING','SENT','FAILED','CANCELLED'))
) ENGINE=InnoDB COMMENT='가족·시니어·선생님 알림 발송 이력';

CREATE TABLE audit_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  actor_user_id BIGINT UNSIGNED NULL,
  action VARCHAR(80) NOT NULL COMMENT 'VIEW_REPORT/UPDATE_ADDRESS 등',
  resource_type VARCHAR(80) NOT NULL,
  resource_id VARCHAR(80) NULL,
  ip_address VARBINARY(16) NULL COMMENT 'IPv4/IPv6 packed binary',
  user_agent VARCHAR(500) NULL,
  result VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
  metadata JSON NULL COMMENT '민감 원문 포함 금지',
  occurred_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_audit_actor_time (actor_user_id, occurred_at),
  KEY idx_audit_resource_time (resource_type, resource_id, occurred_at),
  KEY idx_audit_occurred (occurred_at),
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT chk_audit_result CHECK (result IN ('SUCCESS','DENIED','FAILED'))
) ENGINE=InnoDB COMMENT='관리자·사용자의 민감정보 접근 및 변경 감사 로그';

-- 6. 결제와 B2B/B2G --------------------------------------------------------

CREATE TABLE organizations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_type VARCHAR(20) NOT NULL COMMENT 'COMPANY/GOVERNMENT/PARTNER',
  name VARCHAR(150) NOT NULL,
  business_number VARCHAR(20) NULL,
  contact_name VARCHAR(80) NULL,
  contact_email VARCHAR(255) NULL,
  contact_phone VARCHAR(30) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_organizations_business_no (business_number),
  CONSTRAINT chk_organizations_type CHECK (organization_type IN ('COMPANY','GOVERNMENT','PARTNER')),
  CONSTRAINT chk_organizations_status CHECK (status IN ('ACTIVE','INACTIVE'))
) ENGINE=InnoDB COMMENT='기업 복지·정부 바우처·제휴 기관';

CREATE TABLE organization_members (
  organization_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  member_no VARCHAR(80) NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'MEMBER',
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  joined_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (organization_id, user_id),
  CONSTRAINT fk_org_members_org FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
  CONSTRAINT fk_org_members_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT chk_org_members_role CHECK (role IN ('ADMIN','MEMBER')),
  CONSTRAINT chk_org_members_status CHECK (status IN ('ACTIVE','INACTIVE'))
) ENGINE=InnoDB COMMENT='기관 담당자 또는 복지 대상 회원';

CREATE TABLE vouchers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  learner_id BIGINT UNSIGNED NULL,
  code VARCHAR(80) NOT NULL,
  name VARCHAR(150) NOT NULL,
  total_amount DECIMAL(12,0) UNSIGNED NOT NULL,
  remaining_amount DECIMAL(12,0) UNSIGNED NOT NULL,
  valid_from DATE NOT NULL,
  valid_to DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ISSUED',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_vouchers_code (code),
  KEY idx_vouchers_learner_status (learner_id, status, valid_to),
  CONSTRAINT fk_vouchers_org FOREIGN KEY (organization_id) REFERENCES organizations(id),
  CONSTRAINT fk_vouchers_learner FOREIGN KEY (learner_id) REFERENCES learners(id) ON DELETE SET NULL,
  CONSTRAINT chk_vouchers_amount CHECK (remaining_amount <= total_amount),
  CONSTRAINT chk_vouchers_period CHECK (valid_from <= valid_to),
  CONSTRAINT chk_vouchers_status CHECK (status IN ('ISSUED','ACTIVE','USED','EXPIRED','CANCELLED'))
) ENGINE=InnoDB COMMENT='기업 복지포인트 및 공공 바우처';

CREATE TABLE payment_orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_no VARCHAR(50) NOT NULL,
  enrollment_id BIGINT UNSIGNED NOT NULL,
  purchaser_user_id BIGINT UNSIGNED NOT NULL,
  voucher_id BIGINT UNSIGNED NULL,
  order_amount DECIMAL(12,0) UNSIGNED NOT NULL,
  voucher_amount DECIMAL(12,0) UNSIGNED NOT NULL DEFAULT 0,
  payable_amount DECIMAL(12,0) UNSIGNED NOT NULL,
  billing_period_start DATE NOT NULL,
  billing_period_end DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  paid_at DATETIME(3) NULL,
  cancelled_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_payment_orders_no (order_no),
  KEY idx_payment_orders_enrollment (enrollment_id, created_at),
  KEY idx_payment_orders_status (status, created_at),
  CONSTRAINT fk_orders_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id),
  CONSTRAINT fk_orders_purchaser FOREIGN KEY (purchaser_user_id) REFERENCES users(id),
  CONSTRAINT fk_orders_voucher FOREIGN KEY (voucher_id) REFERENCES vouchers(id) ON DELETE SET NULL,
  CONSTRAINT chk_orders_amount CHECK (order_amount = voucher_amount + payable_amount),
  CONSTRAINT chk_orders_period CHECK (billing_period_start <= billing_period_end),
  CONSTRAINT chk_orders_status CHECK (status IN ('PENDING','PAID','FAILED','CANCELLED','PARTIALLY_REFUNDED','REFUNDED'))
) ENGINE=InnoDB COMMENT='월 이용료 주문';

CREATE TABLE payment_transactions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  payment_order_id BIGINT UNSIGNED NOT NULL,
  transaction_type VARCHAR(20) NOT NULL COMMENT 'PAYMENT/REFUND/VOUCHER_USE',
  provider VARCHAR(40) NOT NULL,
  provider_transaction_id VARCHAR(120) NULL,
  amount DECIMAL(12,0) UNSIGNED NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  requested_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at DATETIME(3) NULL,
  failure_code VARCHAR(80) NULL,
  failure_message VARCHAR(500) NULL,
  raw_response JSON NULL COMMENT '카드번호 등 민감정보 저장 금지',
  PRIMARY KEY (id),
  UNIQUE KEY uk_payment_provider_tx (provider, provider_transaction_id),
  KEY idx_transactions_order (payment_order_id, requested_at),
  CONSTRAINT fk_transactions_order FOREIGN KEY (payment_order_id) REFERENCES payment_orders(id),
  CONSTRAINT chk_transactions_type CHECK (transaction_type IN ('PAYMENT','REFUND','VOUCHER_USE')),
  CONSTRAINT chk_transactions_status CHECK (status IN ('PENDING','SUCCEEDED','FAILED','CANCELLED'))
) ENGINE=InnoDB COMMENT='PG 결제·환불·바우처 차감 원장';

CREATE TABLE voucher_usages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  voucher_id BIGINT UNSIGNED NOT NULL,
  payment_order_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(12,0) UNSIGNED NOT NULL,
  usage_type VARCHAR(20) NOT NULL DEFAULT 'USE',
  used_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_voucher_usages_voucher (voucher_id, used_at),
  CONSTRAINT fk_voucher_usages_voucher FOREIGN KEY (voucher_id) REFERENCES vouchers(id),
  CONSTRAINT fk_voucher_usages_order FOREIGN KEY (payment_order_id) REFERENCES payment_orders(id),
  CONSTRAINT chk_voucher_usage_type CHECK (usage_type IN ('USE','RESTORE'))
) ENGINE=InnoDB COMMENT='바우처 사용/복원 원장';

-- express-mysql-session 기본 호환 테이블. expires는 Unix timestamp(초).
CREATE TABLE sessions (
  session_id VARCHAR(128) COLLATE utf8mb4_bin NOT NULL,
  expires INT UNSIGNED NOT NULL,
  data MEDIUMTEXT COLLATE utf8mb4_bin,
  PRIMARY KEY (session_id),
  KEY idx_sessions_expires (expires)
) ENGINE=InnoDB COMMENT='Express 로그인 세션';

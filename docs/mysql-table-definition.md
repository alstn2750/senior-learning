# 이음학습 MySQL 테이블 정의서

## 1. 적용 기준

- 대상 DBMS: MySQL 8.0.16 이상
- 기본 엔진/문자셋: InnoDB, `utf8mb4`, `utf8mb4_0900_ai_ci`
- 시간 정책: DB에는 UTC `DATETIME(3)`로 저장하고 화면에서 `Asia/Seoul`로 변환한다.
- PK 정책: 업무 테이블은 `BIGINT UNSIGNED AUTO_INCREMENT`를 사용한다. 외부에 노출하는 프로그램 주소는 숫자 PK 대신 `programs.slug`를 사용한다.
- 삭제 정책: 계정·학습자·프로그램·선생님처럼 이력 보존이 필요한 데이터는 `deleted_at`을 이용해 논리 삭제한다. 수업·결제·동의·안전 이벤트는 원장 성격이므로 물리 삭제하지 않는다.
- 상태값: DB에는 영문 코드, 화면에는 한글 라벨을 사용한다. 상태 전이는 애플리케이션 트랜잭션으로 통제한다.
- 개인정보: 비밀번호는 bcrypt 해시만, NFC/공유 토큰은 SHA-256 이상의 단방향 해시만 저장한다. 카드번호·주민등록번호·NFC 원문은 저장하지 않는다.

실행 가능한 전체 DDL은 [`database/schema.sql`](../database/schema.sql)에 있다.

## 2. 테이블 관계 요약

| 영역 | 테이블 | 설명 |
|---|---|---|
| 회원 | `users` | 로그인 계정 |
| 회원 | `learners` | 실제 수업을 받는 시니어 |
| 회원 | `learner_guardians` | 학습자와 가족 계정 연결 및 조회 권한 |
| 회원 | `addresses` | 방문 수업 주소 |
| 회원 | `user_consents` | 약관·개인정보·위치·리포트 공유 동의 이력 |
| 상품 | `centers` | 센터 수업 장소 |
| 안전 | `nfc_tags` | 방문지·센터에 등록된 도착 인증 태그 |
| 상품 | `program_categories` | 디지털, 웰니스, 인지 등 분야 |
| 상품 | `programs` | 프로그램 기본 정보 |
| 상품 | `program_recommendations` | 추천 대상 문구 |
| 상품 | `program_curriculum` | 수업 구성 항목 |
| 상품 | `program_price_options` | 방문/센터·주간 횟수별 가격 이력 |
| 강사 | `teachers` | 선생님 공개·운영 프로필 |
| 강사 | `teacher_specialties` | 선생님 전문 분야 |
| 강사 | `teacher_verifications` | 신원·경력·자격·교육 검증 이력 |
| 강사 | `teacher_service_areas` | 방문 가능 지역과 소속 센터 |
| 강사 | `teacher_availability` | 요일·시간별 가능 일정 |
| 서비스 | `enrollments` | 프로그램 이용 신청/구독 |
| 서비스 | `teacher_match_requests` | 선생님 요청과 최종 배정 |
| 서비스 | `class_sessions` | 회차별 수업 일정 |
| 서비스 | `teacher_reviews` | 완료 수업의 선생님 후기 |
| 안전 | `session_safety_events` | NFC 도착, 수업 종료, 귀가 등 이벤트 |
| 안전 | `location_share_sessions` | 제한 시간 GPS 공유 세션 |
| 리포트 | `learning_records` | 수업 활동·참여 기록 |
| 리포트 | `care_reports` | 기분·활력·집중과 가족 대화 제안 |
| 알림 | `notifications` | 앱/SMS/푸시/이메일 발송 이력 |
| 보안 | `audit_logs` | 민감정보 조회·변경 감사 로그 |
| B2B/B2G | `organizations` | 기업·정부·제휴 기관 |
| B2B/B2G | `organization_members` | 기관 담당자·복지 대상자 |
| B2B/B2G | `vouchers` | 복지포인트·공공 바우처 잔액 |
| 결제 | `payment_orders` | 월 이용료 청구 주문 |
| 결제 | `payment_transactions` | PG 결제·환불·바우처 거래 원장 |
| 결제 | `voucher_usages` | 바우처 사용·복원 원장 |
| 인증 | `sessions` | Express 로그인 세션 |

## 3. 상세 정의

표의 `N`은 NOT NULL, `Y`는 NULL 허용을 뜻한다. 공통 감사 컬럼인 `created_at`, `updated_at`, `deleted_at`은 각 DDL 정의를 따른다.

### 3.1 `users`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 사용자 식별자 |
| `email` | VARCHAR(255) | N | UK | 로그인 이메일, 소문자로 정규화 후 저장 |
| `password_hash` | VARCHAR(255) | Y |  | bcrypt 해시 |
| `name` | VARCHAR(80) | N |  | 가입자 이름 |
| `phone` | VARCHAR(30) | Y |  | E.164 또는 국내 표준 형식으로 정규화 |
| `account_type` | VARCHAR(20) | N | IDX | `SENIOR/FAMILY/TEACHER/ADMIN` |
| `status` | VARCHAR(20) | N | IDX | `PENDING/ACTIVE/SUSPENDED/WITHDRAWN` |
| `email_verified_at` | DATETIME(3) | Y |  | 이메일 인증 시각 |
| `last_login_at` | DATETIME(3) | Y |  | 마지막 로그인 시각 |

### 3.2 `learners`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 학습자 식별자 |
| `user_id` | BIGINT UNSIGNED | Y | FK, UK | 시니어 본인 계정 |
| `name` | VARCHAR(80) | N |  | 학습자 이름 |
| `birth_date` | DATE | Y |  | 나이는 조회 시 계산 |
| `phone` | VARCHAR(30) | Y |  | 본인 연락처 |
| `preferred_contact` | VARCHAR(20) | N |  | `SELF/GUARDIAN` |
| `accessibility_notes` | VARCHAR(500) | Y |  | 큰 글씨, 이동 편의 등 요청 |
| `emergency_contact_name` | VARCHAR(80) | Y |  | 긴급 연락 대상 이름 |
| `emergency_contact_phone` | VARCHAR(30) | Y |  | 긴급 연락처 |
| `status` | VARCHAR(20) | N |  | `ACTIVE/INACTIVE` |

### 3.3 `learner_guardians`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `learner_id` | BIGINT UNSIGNED | N | PK, FK | 학습자 |
| `user_id` | BIGINT UNSIGNED | N | PK, FK | 가족 계정 |
| `relationship` | VARCHAR(30) | Y |  | 딸, 아들, 배우자 등 |
| `is_primary` | TINYINT(1) | N |  | 대표 보호자 여부 |
| `can_view_reports` | TINYINT(1) | N |  | 리포트 조회 권한 |
| `can_receive_safety_alerts` | TINYINT(1) | N |  | 안전 알림 수신 권한 |
| `can_manage_enrollment` | TINYINT(1) | N |  | 프로그램 신청 변경 권한 |

### 3.4 `addresses`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 주소 식별자 |
| `learner_id` | BIGINT UNSIGNED | N | FK, IDX | 학습자 |
| `label` | VARCHAR(40) | N |  | 집, 자녀 집 등 |
| `postal_code` | VARCHAR(10) | Y |  | 우편번호 |
| `address_line1/2` | VARCHAR(255) | N/Y |  | 기본/상세 주소 |
| `latitude/longitude` | DECIMAL(10,7) | Y |  | 방문 위치 좌표 |
| `access_notes` | VARCHAR(500) | Y |  | 공동현관·주차 등 안내 |
| `is_default` | TINYINT(1) | N | IDX | 기본 방문지 여부 |

### 3.5 `user_consents`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 동의 이력 식별자 |
| `user_id` | BIGINT UNSIGNED | N | FK | 동의한 사용자 |
| `learner_id` | BIGINT UNSIGNED | Y | FK | 동의 대상 학습자, 공통 약관은 NULL |
| `learner_scope_id` | BIGINT UNSIGNED | N | UK | NULL 범위 중복 방지용 생성 컬럼 |
| `consent_type` | VARCHAR(40) | N | UK | `TERMS/PRIVACY/LOCATION/REPORT_SHARE/MARKETING` |
| `policy_version` | VARCHAR(30) | N | UK | 약관 버전 |
| `is_agreed` | TINYINT(1) | N |  | 동의 여부 |
| `agreed_at/revoked_at` | DATETIME(3) | Y |  | 동의/철회 시각 |

### 3.6 `centers`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 센터 식별자 |
| `name` | VARCHAR(120) | N |  | 센터명 |
| `phone` | VARCHAR(30) | Y |  | 대표 연락처 |
| `postal_code`, `address_line1/2` | VARCHAR | 혼합 |  | 센터 주소 |
| `latitude/longitude` | DECIMAL(10,7) | Y |  | 지도 좌표 |
| `operating_hours` | JSON | Y |  | 요일별 운영시간 |
| `capacity` | SMALLINT UNSIGNED | Y |  | 동시 수용 인원 |
| `status` | VARCHAR(20) | N | IDX | `PREPARING/ACTIVE/INACTIVE` |

### 3.7 `nfc_tags`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 태그 식별자 |
| `tag_uid_hash` | CHAR(64) | N | UK | NFC UID 단방향 해시 |
| `address_id` | BIGINT UNSIGNED | Y | FK, IDX | 방문지 태그인 경우 주소 |
| `center_id` | BIGINT UNSIGNED | Y | FK, IDX | 센터 태그인 경우 센터 |
| `label` | VARCHAR(80) | N |  | 설치 위치 표시명 |
| `status` | VARCHAR(20) | N | IDX | `ACTIVE/REVOKED/LOST` |
| `activated_at/revoked_at` | DATETIME(3) | N/Y |  | 활성·폐기 시각 |

`address_id`와 `center_id` 중 정확히 하나만 존재해야 한다. 도착 인증 시 전달된 UID를 같은 방식으로 해시해 활성 태그와 비교하며 원문 UID는 보관하지 않는다.

### 3.8 프로그램 테이블

| 테이블 | 주요 컬럼 | 키/관계 | 설명 |
|---|---|---|---|
| `program_categories` | `code`, `name`, `sort_order`, `is_active` | `code` UK | 프로그램 분야 코드 |
| `programs` | `category_id`, `slug`, `title`, `level`, `summary`, `description`, `icon`, `color_code`, `medical_disclaimer`, `status` | category FK, `slug` UK | 프로그램 본문과 공개 상태 |
| `program_recommendations` | `program_id`, `content`, `sort_order` | program FK | “이런 분께 추천” 항목 |
| `program_curriculum` | `program_id`, `title`, `description`, `sort_order` | program FK | 커리큘럼 항목 |
| `program_price_options` | `program_id`, `service_mode`, `weekly_frequency`, `monthly_price`, `currency`, `valid_from/to`, `is_active` | program FK, 조건·시작일 UK | 방문/센터와 횟수별 가격 이력 |

`service_mode`은 `HOME/CENTER`, 프로그램 `status`는 `DRAFT/ACTIVE/PAUSED/ARCHIVED`를 사용한다. 신청 이후 가격이 바뀌어도 계약 금액이 변하지 않도록 `enrollments.monthly_price`에 신청 당시 금액을 복사한다.

### 3.9 선생님 테이블

| 테이블 | 주요 컬럼 | 키/관계 | 설명 |
|---|---|---|---|
| `teachers` | `user_id`, `display_name`, `bio`, `career_summary`, `career_years`, `rating`, `review_count`, `status`, `hired_at` | user FK/UK | 공개 프로필과 활동 상태 |
| `teacher_specialties` | `teacher_id`, `category_id`, `years_experience`, `is_primary` | 복합 PK | 전문 분야 다대다 연결 |
| `teacher_verifications` | `teacher_id`, `verification_type`, `title`, `issuer`, `reference_no`, `verified_at`, `expires_at`, `status`, `reviewer_user_id` | teacher/reviewer FK | 검증 및 만료 이력 |
| `teacher_service_areas` | `teacher_id`, `sido`, `sigungu`, `eupmyeondong`, `service_mode`, `center_id`, `travel_radius_km` | teacher/center FK | 방문 지역 또는 센터 연결 |
| `teacher_availability` | `teacher_id`, `day_of_week`, `start_time`, `end_time`, `service_mode`, `is_active` | teacher FK | 반복 가능 시간 |

검증 종류는 `IDENTITY/CAREER/CERTIFICATE/SAFETY/EMERGENCY/COMMUNICATION`, 검증 상태는 `PENDING/VERIFIED/REJECTED/EXPIRED`다. `reference_no`에 주민등록번호나 자격증 원본을 넣지 않으며 필요하면 별도의 암호화 문서 저장소 키만 보관한다.

### 3.10 `enrollments`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 이용 신청 식별자 |
| `learner_id` | BIGINT UNSIGNED | N | FK, IDX | 학습자 |
| `program_id` | BIGINT UNSIGNED | N | FK, IDX | 프로그램 |
| `price_option_id` | BIGINT UNSIGNED | N | FK | 선택 가격 옵션 |
| `purchaser_user_id` | BIGINT UNSIGNED | N | FK, IDX | 신청·결제 주체 |
| `payer_type` | VARCHAR(20) | N |  | `SELF/FAMILY/ORGANIZATION/VOUCHER` |
| `service_mode` | VARCHAR(20) | N |  | `HOME/CENTER` |
| `weekly_frequency` | TINYINT UNSIGNED | N |  | 주간 수업 횟수 |
| `monthly_price` | DECIMAL(12,0) | N |  | 신청 당시 월 금액 |
| `preferred_schedule` | VARCHAR(300) | Y |  | 희망 일정 자유 입력 |
| `status` | VARCHAR(20) | N | IDX | `PENDING/ACTIVE/PAUSED/COMPLETED/CANCELLED` |
| `start_date/end_date` | DATE | Y |  | 이용 기간 |
| `cancelled_at`, `cancellation_reason` | DATETIME/VARCHAR | Y |  | 취소 정보 |

### 3.11 `teacher_match_requests`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 요청 식별자 |
| `enrollment_id` | BIGINT UNSIGNED | N | FK, IDX | 이용 신청 |
| `requested_teacher_id` | BIGINT UNSIGNED | Y | FK | 사용자가 고른 선생님 |
| `assigned_teacher_id` | BIGINT UNSIGNED | Y | FK | 최종 배정 선생님 |
| `requested_by_user_id` | BIGINT UNSIGNED | N | FK | 요청자 |
| `preferred_time` | VARCHAR(200) | Y |  | 희망 시간 |
| `message` | VARCHAR(1000) | Y |  | 전달 사항 |
| `service_mode` | VARCHAR(20) | N |  | `HOME/CENTER` |
| `status` | VARCHAR(20) | N | IDX | `RECEIVED/REVIEWING/OFFERED/MATCHED/DECLINED/CANCELLED` |
| `responded_at` | DATETIME(3) | Y |  | 응답 완료 시각 |

### 3.12 `class_sessions`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 회차 식별자 |
| `enrollment_id`, `teacher_id`, `learner_id` | BIGINT UNSIGNED | N | FK, IDX | 신청·선생님·학습자 |
| `center_id` | BIGINT UNSIGNED | Y | FK | 센터 수업 장소 |
| `address_id` | BIGINT UNSIGNED | Y | FK | 방문 수업 장소 |
| `service_mode` | VARCHAR(20) | N |  | 방문은 주소, 센터는 센터가 필수 |
| `subject` | VARCHAR(200) | N |  | 해당 회차 주제 |
| `scheduled_start_at/end_at` | DATETIME(3) | N | IDX | 예정 시간 |
| `actual_start_at/end_at` | DATETIME(3) | Y |  | 실제 시간 |
| `status` | VARCHAR(20) | N | IDX | `SCHEDULED/TEACHER_EN_ROUTE/ARRIVED/IN_PROGRESS/COMPLETED/CANCELLED/NO_SHOW` |
| `cancelled_by_user_id`, `cancellation_reason` | BIGINT/VARCHAR | Y | FK | 취소 정보 |

### 3.13 `teacher_reviews`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 후기 식별자 |
| `class_session_id` | BIGINT UNSIGNED | N | FK, UK | 완료된 수업 회차 |
| `teacher_id` | BIGINT UNSIGNED | N | FK, IDX | 평가 대상 선생님 |
| `author_user_id` | BIGINT UNSIGNED | N | FK, UK | 작성자 |
| `rating` | TINYINT UNSIGNED | N |  | 1~5점 |
| `content` | VARCHAR(2000) | Y |  | 후기 본문 |
| `status` | VARCHAR(20) | N | IDX | `PUBLISHED/HIDDEN/REPORTED` |

동일 사용자는 한 수업에 한 번만 작성할 수 있다. `teachers.rating`과 `review_count`는 공개 목록 성능을 위한 집계 캐시이며 후기 생성·숨김 시 트랜잭션 또는 비동기 집계로 갱신한다.

### 3.14 안전 테이블

| 테이블 | 주요 컬럼 | 키/관계 | 설명 |
|---|---|---|---|
| `session_safety_events` | `class_session_id`, `event_type`, `event_status`, `actor_user_id`, `occurred_at`, `latitude`, `longitude`, `nfc_token_hash`, `metadata` | session/actor FK | 일정 확정부터 강사 귀가까지 이벤트 원장 |
| `location_share_sessions` | `class_session_id`, `teacher_id`, `consent_id`, `share_token_hash`, `started_at`, `expires_at`, `ended_at`, 마지막 좌표/시각, `status` | session/teacher/consent FK | 동의와 만료가 있는 위치 공유 세션 |

안전 이벤트 종류는 `SCHEDULE_CONFIRMED/TEACHER_DEPARTED/NFC_ARRIVAL/GPS_SHARED/CLASS_STARTED/CLASS_ENDED/TEACHER_RETURNED/EMERGENCY`다. GPS는 상시 추적하지 않고 방문에 필요한 짧은 시간만 공유하며, 원본 이동경로는 기본 스키마에 저장하지 않는다.

### 3.15 학습·안부 리포트

| 테이블 | 주요 컬럼 | 키/관계 | 설명 |
|---|---|---|---|
| `learning_records` | `class_session_id`, `enrollment_id`, `learner_id`, `teacher_id`, `participation_score`, `activity_title`, `note`, `next_activity` | 회차 UK, 관련 FK | 회차별 활동과 참여 기록 |
| `care_reports` | `class_session_id`, `learner_id`, `teacher_id`, `mood_score`, `energy_score`, `focus_score`, `observation_note`, `family_prompt`, `published_at` | 회차 UK, 관련 FK | 수업 후 가족 안부 리포트 |

기분·활력·집중은 1~5 범위다. 이는 의료 진단값이 아니라 수업 중 관찰 지표이며, 진단명·질환 예측값을 이 테이블에 기록하지 않는다.

### 3.16 `notifications`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 알림 식별자 |
| `user_id` | BIGINT UNSIGNED | N | FK, IDX | 수신자 |
| `class_session_id` | BIGINT UNSIGNED | Y | FK | 관련 수업 |
| `notification_type` | VARCHAR(40) | N |  | 도착·종료·리포트·결제 등 |
| `channel` | VARCHAR(20) | N |  | `IN_APP/SMS/PUSH/EMAIL` |
| `title/body` | VARCHAR | N |  | 알림 내용 |
| `payload` | JSON | Y |  | 화면 이동 등 비민감 부가정보 |
| `status` | VARCHAR(20) | N | IDX | `PENDING/SENT/FAILED/CANCELLED` |
| `scheduled_at/sent_at/read_at` | DATETIME(3) | Y |  | 예약·발송·읽음 시각 |
| `failure_reason` | VARCHAR(500) | Y |  | 발송 실패 사유 |

### 3.17 `audit_logs`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `id` | BIGINT UNSIGNED | N | PK | 감사 로그 식별자 |
| `actor_user_id` | BIGINT UNSIGNED | Y | FK, IDX | 작업 사용자, 시스템 작업은 NULL |
| `action` | VARCHAR(80) | N |  | `VIEW_REPORT`, `UPDATE_ADDRESS` 등 |
| `resource_type/resource_id` | VARCHAR(80) | N/Y | IDX | 대상 종류와 식별자 |
| `ip_address` | VARBINARY(16) | Y |  | IPv4/IPv6 packed 값 |
| `user_agent` | VARCHAR(500) | Y |  | 요청 클라이언트 |
| `result` | VARCHAR(20) | N |  | `SUCCESS/DENIED/FAILED` |
| `metadata` | JSON | Y |  | 비민감 부가정보 |
| `occurred_at` | DATETIME(3) | N | IDX | 발생 시각 |

### 3.18 기관·바우처·결제

| 테이블 | 주요 컬럼 | 키/관계 | 설명 |
|---|---|---|---|
| `organizations` | `organization_type`, `name`, `business_number`, 담당자 정보, `status` | 사업자번호 UK | B2B/B2G 기관 |
| `organization_members` | `organization_id`, `user_id`, `member_no`, `role`, `status`, `joined_at` | 복합 PK | 기관 담당자·복지 회원 |
| `vouchers` | `organization_id`, `learner_id`, `code`, `total_amount`, `remaining_amount`, 유효기간, `status` | code UK | 바우처 잔액 |
| `payment_orders` | `order_no`, `enrollment_id`, `purchaser_user_id`, `voucher_id`, 주문/바우처/실결제 금액, 청구기간, `status` | order_no UK | 월 청구 주문 |
| `payment_transactions` | `payment_order_id`, `transaction_type`, `provider`, `provider_transaction_id`, `amount`, `status`, 실패 정보, `raw_response` | PG 거래번호 UK | 결제·환불 원장 |
| `voucher_usages` | `voucher_id`, `payment_order_id`, `amount`, `usage_type`, `used_at` | 관련 FK | 바우처 차감·복원 원장 |

주문 금액은 `order_amount = voucher_amount + payable_amount`를 만족해야 한다. 결제 승인과 바우처 잔액 차감은 한 DB 트랜잭션에서 처리하고, PG 웹훅은 `provider_transaction_id`로 멱등 처리한다.

### 3.19 `sessions`

| 컬럼 | 타입 | NULL | 키 | 설명 |
|---|---|---:|---|---|
| `session_id` | VARCHAR(128) | N | PK | Express 세션 ID |
| `expires` | INT UNSIGNED | N | IDX | Unix timestamp(초) |
| `data` | MEDIUMTEXT | Y |  | 직렬화된 세션 데이터 |

`express-mysql-session` 기본 규격과 호환된다. 운영 환경에서는 세션 쿠키에 `httpOnly`, `secure`, `sameSite`를 설정하고 만료 세션 정리 작업을 활성화한다.

## 4. 현재 JSON 데이터 이전표

| 기존 데이터 | 목적 테이블/컬럼 |
|---|---|
| `users.json`의 계정 정보 | `users` |
| `learnerName`, `learnerAge` | `learners.name`, 생년월일을 확인해 `learners.birth_date` |
| `relationship` | `learner_guardians.relationship` |
| `plans.json` 기본 정보 | `program_categories`, `programs` |
| `benefits[]` | `program_recommendations` |
| `curriculum[]` | `program_curriculum` |
| `price`, 방문/센터, 횟수 | `program_price_options` |
| `teachers.json` | `teachers`, `teacher_specialties`, `teacher_verifications`, `teacher_service_areas` |
| `enrollments.json` | `enrollments`; 중첩 `progress[]`는 `class_sessions`와 `learning_records`로 분리 |
| `matchRequests.json` | `teacher_match_requests` |
| `visits.json` | `class_sessions`; `safetySteps[]`는 `session_safety_events` |
| `careReports.json` | `care_reports` |

## 5. 필수 트랜잭션 경계

1. 프로그램 신청: `enrollments` 생성과 최초 `teacher_match_requests` 생성을 한 트랜잭션으로 처리한다.
2. 매칭 확정: 요청 상태를 `MATCHED`로 바꾸고 배정 선생님을 기록한 뒤 최초 `class_sessions` 일정을 생성한다.
3. 수업 종료: 수업 상태, `CLASS_ENDED` 안전 이벤트, 학습 기록, 안부 리포트, 가족 알림 예약을 함께 처리한다.
4. 월 결제: 주문 생성, PG 거래 반영, 바우처 차감, 주문 상태 변경을 멱등 트랜잭션으로 처리한다.
5. 회원 탈퇴: 계정을 `WITHDRAWN` 처리하고 법적 보존 대상이 아닌 개인정보는 분리된 비동기 작업에서 익명화한다.

## 6. 권장 보존·보안 원칙

- 위치 공유 세션은 종료 즉시 접근 불가능하게 만들고 마지막 좌표도 운영상 필요한 최소 기간 후 삭제한다.
- 안전 이벤트와 결제 원장은 수정 대신 반대 이벤트 또는 환불 거래를 추가한다.
- 주소, 연락처, 관찰 리포트는 서비스 계정에서 직접 조회하지 못하도록 최소 권한 DB 계정을 분리한다.
- 운영 로그에는 이메일, 전화번호, 상세 주소, 위치 좌표, 리포트 본문을 남기지 않는다.
- 백업 암호화와 복구 훈련, 관리자 조회 감사 로그는 실제 운영 전 별도 구현해야 한다.

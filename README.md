# 총무노트

누구나 쓰는 모임 회비 장부 앱(안드로이드)이에요. 총무가 모임을 만들고 초대코드로 회원을 부르면,
총무가 기록한 내용이 회원 모두의 폰에 바로 반영돼요. 모임마다 장부가 따로라서 여러 모임에 들어가도 기록이 섞이지 않아요.

## 들어 있는 것

- **모임 만들기**: 이름, 사진(선택), 색, 한 달 회비(없어도 됨), 시작 잔고 → 만든 사람이 총무
- **초대코드**: 6자리 코드 + 카톡에 붙여넣을 초대 글 복사. 받은 사람은 코드 입력 → 명단에서 이름 고르거나 새 이름으로 가입 신청 → 총무 승인
- **여러 모임**: 홈 제목(모임 이름)을 누르면 내 모임 목록으로. 마지막에 본 모임이 다음에 바로 열려요
- **총무 설정**: 모임 이름·사진·색, 한 달 회비·시작 잔고, 수입·지출 분류 더하기/빼기, 회원 넣기/빼기, 회비 면제, 생일, 회장 정하기, 총무 넘기기, 초대코드 새로 만들기
- **장부·회비·모임·소식**: 입출금 기록, 월간/연간 그래프, 회비 미납 현황, 모임 기록과 참석률, 지역 돌아가기(켜고 끄기·지역 직접 입력), 공지와 투표, 메시지
- 애플 스타일 디자인, 다크 모드, 세로/가로 화면, 폰 글씨 크기 (최대 1.3배)
- 새 버전이 나오면 앱이 알려주고 바로 업데이트

## 실행 모드

| 모드 | 언제 | 데이터 |
| --- | --- | --- |
| 실제 모드 | 안드로이드 앱 | Firebase 프로젝트 `finance-note-f37c8`에 실시간 저장 + 구글 로그인 |
| 체험 모드 | 웹 미리보기, 테스트 | 지어낸 예시 모임("우리 모임")이 앱 안에 들어 있고, 바꾼 내용은 저장되지 않음 |

## Firebase 설정 (한 번만)

- Authentication → Google 로그인 사용
- Firestore → 규칙 탭에 [`firestore.rules`](firestore.rules) 내용 붙여넣고 게시
- 프로젝트 설정 → 내 앱 → 릴리스 서명 키의 SHA-1 지문 등록

## 설치 파일(APK)

GitHub Actions가 자동으로 만들어요 ([`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml)).

- 회원에게 줄 고정 링크 (항상 최신): https://github.com/uknowsk/finance-note/releases/latest/download/chongmu-note.apk
- main에 올라갈 때 `pubspec.yaml` 버전의 Release가 없으면 새로 만들어요. 새 버전은 버전 숫자만 올리면 돼요
- 서명 키는 저장소 Secrets에 `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`로 넣어 둬요. 키 파일은 저장소에 올리지 않아요

## Firestore 구조

| 경로 | 내용 |
| --- | --- |
| `users/{uid}` | 내가 들어간·신청한 모임 목록, 마지막으로 본 모임 |
| `invites/{코드}` | 초대코드 → 모임 id |
| `groups/{gid}` | 모임 이름, 색, 사진(작게 줄인 JPG), 초대코드, 만든 사람 |
| `groups/{gid}/accounts/{uid}` | 로그인 계정 ↔ 회원 연결, 역할 (보안 규칙이 권한을 여기서 읽음) |
| `groups/{gid}/members/{id}` | 회원 명단: 이름, 역할, 연결된 uid, 면제 연도, 생일 |
| `groups/{gid}/joinRequests/{uid}` | 가입 신청 |
| `groups/{gid}/transactions/{id}` | 입출금 기록 |
| `groups/{gid}/config/settings` | 시작 잔고, 월 회비, 분류, 회장, 지역 순서 |
| `groups/{gid}/meetings`, `notices`, `messages` | 모임 기록, 공지·투표, 메시지 |

## 개발

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --no-web-resources-cdn   # 체험 모드 미리보기
```

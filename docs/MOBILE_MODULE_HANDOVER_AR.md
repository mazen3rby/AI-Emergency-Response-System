# تقرير تسليم وحدة الطوارئ للموبايل — عربي (مصرى)

**التاريخ:** 2026-11-17  
**النطاق:** وحدة الطوارئ للموبايل (Flutter Android) فقط.  
**الريبو:** https://github.com/mazen3rby/AI-Emergency-Response-System  
**الفرع المحلي الحالي:** `fix/mobile-emergency-remediation`  
**الـ commit المتوقع:** `83144174f21d7264a4013579492118809a64d706`  
**طبيعة المهمة:** فحص قرائي + توثيق فقط. لم أعدّل كود تطبيق، ولم أنشئ commit، ولم أدفع، ولم أدمج، ولم أغيّر إعدادات Git. لم أطبع أي محتوى من `android/app/google-services.json`.

> مصادر التحقق: `git status`، `git branch -vv`، `git log --oneline --decorate -8`، `git remote -v`، `git ls-remote --heads origin`، `git ls-remote origin`، GitHub API، وفحص فعلي لكل ملفات Dart وملفات الإعداد والمستندات المذكورة أدناه.

---

## 1. هل شغلي اترفع على GitHub فعلًا؟

**الإجابة القصيرة: لا. أحدث شغلك غير موجود على GitHub حاليًا.**

تم الوصول لـ GitHub بنجاح، فالتحقق **not inconclusive**؛ أي إنه التحقق حاسم ومؤكد.

| البند | النتيجة الموثقة |
|---|---|
| الفرع المحلي الحالي | `fix/mobile-emergency-remediation` |
| الـ commit الحالي (HEAD) | `83144174f21d7264a4013579492118809a64d706` (المختصر `8314417`) |
| الـ commit السابق في سلسلة الإصلاح | `9a24a71856046d45a42245e0e6c5974fbb515ea3` (المختصر `9a24a71`) |
| الـ remote | `origin` → `https://github.com/mazen3rby/AI-Emergency-Response-System.git` |
| نوع الريبو على GitHub | public (عام) — تم التأكد من GitHub API: `"private": false` |
| `origin/main` على GitHub | `c7f4430d266eef4834cdcd297ae4742961493b2e` |
| حالة التتبّع المحلية | `fix/mobile-emergency-remediation [origin/main: ahead 2]` |
| المتأخر عن الـ remote | 0 |
| المتقدم عن `origin/main` | 2 |
| هل الفرع `fix/mobile-emergency-remediation` موجود على GitHub؟ | **لا** |
| هل الكوميت `9a24a71` موجود على GitHub؟ | **لا** |
| هل الكوميت `8314417` موجود على GitHub؟ | **لا** |
| هل زميلك يقدر يوصل لأحدث كود عن GitHub؟ | **لا** |
| هل فيه تغييرات غير ملتزمة؟ | **نعم** |

### الأدلة التفصيلية

1. `git branch -vv` قال إن الفرع الحالي يتبع `origin/main` (مش فرع بعيد خاص بالـ remediation) وهو `ahead 2`.
2. `git rev-list --left-right --count origin/main...HEAD` أعاد `0  2`، يعني: لا شيء ناقص من main، وعندك كوميتان محليان فقط.
3. `git ls-remote --heads origin` أعاد فرعين فقط:
   - `c7f4430d266eef4834cdcd297ae4742961493b2e refs/heads/main`
   - `f4768df23c4020063cf16d09128beac4e9cf7593 refs/heads/person2/mobile-gps-sos-verified`
4. GitHub API لقائمة الفروع أعاد نفس الفرعين فقط. طلب الفرع `fix/mobile-emergency-remediation` رجع `404`.
5. طلب الكوميتات بالـ hash الكامل رجع `422` لكليهما:
   - `9a24a71856046d45a42245e0e6c5974fbb515ea3`
   - `83144174f21d7264a4013579492118809a64d706`
6. `git ls-remote origin` كمان أظهر `HEAD` + الفرعين فقط، بدون tags وبدون `refs/pull/*`.

### ملاحظة مهمة عن `ahead 2`

`ahead 2` معناه «عندك كوميتان محليان مش موجودين في الـ remote-tracking لـ origin/main». **ومعناة ليسوا مرفوعين.** لازم `ls-remote` أو GitHub API يأكدوا وجود الفرع/الكميت. هنا التأكيد بيقول إنهم **غير موجودين**.

### التغييرات غير الملتزمة

`git status` قال:

```text
modified:   lib/main.dart
modified:   test/mobile_emergency_module_test.dart
```

`git diff --stat` لهما: `2 files changed, 212 insertions(+), 23 deletions(-)`.

يعني حتى لو اترفع الفرع كما هو الآن، هاتين النسختين المعدّلتين مش هتوصّل لزميلك إلا بعد عمل commit لهما. (لم أنفّذ أي commit.)

الفرق بين الفرع الملتزم و`origin/main`:

```text
5 files changed, 1170 insertions(+), 162 deletions(-)
android/app/src/main/AndroidManifest.xml
lib/main.dart
pubspec.lock
pubspec.yaml
test/mobile_emergency_module_test.dart
```

### حالة هذا التقرير نفسه

بعد حفظ هذا الملف، سيظهر في `git status` كملف جديد غير ملتزم تحت `docs/MOBILE_MODULE_HANDOVER_AR.md`. هو أيضًا **غير مرفوع على GitHub**. لم أنشئ له commit.

**الخلاصة:** زميلك يقدر يقرأ `main` و`person2/mobile-gps-sos-verified` فقط. أحدث إصلاحاتك (`9a24a71` + `8314417`) والتعديلات غير الملتزمة موجودة على جهازك فقط.

---

## 2. زميلي يقدر يوصل للكود إزاي؟

### الحالة الحالية (قبل نشر الفرع)

**لا يوجد أمر آمن يجيب الفرع الحالي من GitHub؛ لأن الفرع غير موجود هناك.** لازم تنشره أنت أولًا بعد موافقتك أنت، وأنا لم أفعل ذلك.

الخطوة الآمنة التالية اللي تقدر تعملها أنت (بعد مراجعة التغييرات غير الملتزمة وتقرر إذا كانت جزءًا من التسليم):

```bash
git status
git diff
git add <الملفات-اللي-توافق-على-تسليمها>
git commit -m "<رسالة-تصف-اللي-ات_add>"
git push -u origin fix/mobile-emergency-remediation
```

> أنا **لم أنفّذ** أي أمر من الأوامر دي. لو قررت إن التغييرات غير الملتزمة مش داخل في التسليم، راجعها قبل الـ commit. لو اترفع الفرع، الكوميت الأخير هيبقى commit جديد مش بالضرورة `8314417`؛ لازم تبعته بالـ hash الفعلي وقتها لزميلك.

### بعد ما الفرع يتأكد أنه موجود على GitHub

أول مرة يعمل كده:

```bash
git fetch origin
git checkout -b fix/mobile-emergency-remediation origin/fix/mobile-emergency-remediation
```

أو بصيغة أحدث:

```bash
git fetch origin
git switch --create fix/mobile-emergency-remediation --track origin/fix/mobile-emergency-remediation
```

لو عنده بالفعل فرع محلي بنفس الاسم:

```bash
git fetch origin
git switch fix/mobile-emergency-remediation
git branch --set-upstream-to=origin/fix/mobile-emergency-remediation fix/mobile-emergency-remediation
git pull --ff-only
```

لو `git pull --ff-only` فشل، معناه إن تاريخ الفرع المحلي مختلف عن البعيد. هنا لازم يوقف ويسألك، **وميعملش force-push ولا merge غصب**.

### لو عايز يوصل للكود القديم المتاح دلوقتي

```bash
git clone https://github.com/mazen3rby/AI-Emergency-Response-System.git
cd AI-Emergency-Response-System
git checkout main
```

أو للفرع القديم:

```bash
git checkout person2/mobile-gps-sos-verified
```

بس دول **مش** أحدث شغلك. `main` عند `c7f4430` و`person2/mobile-gps-sos-verified` عند `f4768df`.

### ممنوع

- ميعملش `git merge` إلى `main` أوفرع تاني من غير موافقة.
- ميعملش `git push -f`.
- ميفترضش إن `ahead 2` معناه إن الكود اترفع.

---

## 3. الملفات المهمة ووظيفة كل ملف.

### خريطة سريعة

| الملف | الفئة | الباك إند محتاجه؟ | آمن للتعديل؟ |
|---|---|---|---|
| `lib/main.dart` | UI + business logic + models + services | نعم (النماذج والـ flows مش الـ UI) | ⚠️ لا تعديل مباشر إلا باتفاق؛ فيه UI مجمد واختبارات حساسة |
| `test/mobile_emergency_module_test.dart` | tests | نعم للفهم، ويتوسّع عند إضافة API | آمن لإضافة tests، مش لتغيير السلوك بدون سبب |
| `pubspec.yaml` | config | نعم (الاسم/SDK/الحزم) | بحذر؛ أي إضافة حزمة لازم `flutter pub get` |
| `pubspec.lock` | config | نعم لمطابقة الإصدارات | ❌ لا يُعدّل يدويًا |
| `android/app/src/main/AndroidManifest.xml` | config | نعم (صلاحيات INTERNET/Notifications) | بحذر ومراجعة |
| `android/app/build.gradle.kts` | config | نعم (Firebase plugin/package id) | بحذر |
| `android/build.gradle.kts` | config | نعم بشكل غير مباشر | بحذر |
| `android/app/google-services.json` | config/بيانات Firebase | نعم، لكن **لا يُعرض في الشات** | ❌ لا يُعدّل يدويًا؛ يُولّد من Firebase Console |
| `analysis_options.yaml` | config | لا بشكل مباشر | آمن نسبيًا |
| `main.dart` في جذر الريبو | legacy UI/logic | ❌ لا يستخدم للتكامل | تجاهله |
| `README.md` وملفات الـ handover القديمة | docs | للسياق فقط | آمن |
| `assets/images/*` | UI assets | لا | آمن للقراءة فقط |
| `docs/MOBILE_MODULE_HANDOVER_AR.md` | docs | نعم (هذا التقرير) | آمن؛ ملف جديد غير ملتزم |

### 1) `lib/main.dart`

1. **إيه هو؟** ملف الدخول الحقيقي للتطبيق. `main()` فيه تستدعي `_loadPersistedHistory()` وبعدها `runApp(const EmergencyHelpApp())`.
2. **بيعمل إيه؟** كل حاجة:Models، خدمات GPS، الإشعارات، Firebase، الخريطة، شاشات SOS/Help/History، وحفظ التاريخ محليًا.
3. **البيانات اللي بيديرها؟** `EmergencySession`، `Responder`، `LocationResult`، `LocationSource`، `_RespWithDist`، `AddressInfo`، `TileLoadState`، وحالات الـ static fields في `LiveLocationService` و`NotificationService`.
4. **الباك إند محتاجه؟** نعم، محتاج يقرأ التعريفات والدوال، مش الشاشات نفسها.
5. **هيُستخدم إزاي في التكامل؟** هنا هيتضاف عميل الـ API/Repository لاحقًا، أو تُستبدل الدوال المحلية بـ calls للباك إند بعد الاتفاق على العقد.
6. **آمن للتعديل؟** لا للتعديل العشوائي. أي تغيير في النصوص/الـ flows ممكن يكسر اختبارات «Frozen UI preservation» أو يغيّر سلوك SOS. التعديل لازم يكون بنسخة محفوظة + `flutter analyze/test`.
7. **الفئة:** UI + business logic + data models + service layer بدائية في ملف واحد.

> ملاحظة: البحث عن ملفات `.dart` لقى 3 ملفات فقط: `lib/main.dart`، `test/mobile_emergency_module_test.dart`، و`main.dart` في الجذر. **لا يوجد ملف منفصل للـ GPS أو Firebase أو repository أو models**؛ كل حاجة جوّه `lib/main.dart`.

### 2) `test/mobile_emergency_module_test.dart`

1. **إيه هو؟** ملف الاختبارات الخاص بالوحدة.
2. **بيعمل إيه؟** يختبر السلوك بـ mocks بدون مكالمات حقيقية، بدون إرسال SMS، وبدون رفع بيانات.
3. **البيانات؟** مواقع وهمية، payloads وهمية، وحالات SharedPreferences وهمية.
4. **الباك إند محتاجه؟** نعم، عشان يفهم السلوك المتوقع قبل ما يضيف اختبارات تكامل.
5. **الاستخدام؟** يتضاف له tests للـ API client والـ mapping بعد ما الباك إند يبعت لك الـ schema.
6. **آمن؟** آمن لإضافة اختبارات جديدة. تغيير الاختبارات القديمة لازم يكون مبرر.
7. **الفئة:** tests.

أهم المجموعات الموجودة: `formatAddressLabel`، `AddressInfo`، `getAreaName`، `LocationResult source labeling`، `Cached/mock location fallback classification`، `LiveLocationService permission messages`، `GPS provenance and tracking lifecycle`، `Reverse geocoding cache`، `Tile error/recovery state`، `SOS duplicate prevention`، `SMS and dialer launcher behavior`، `EmergencySession persistence`، `Firebase and notifications`، `Frozen UI preservation`.

**العدد الحالي: 34 test/testWidgets.** المستند القديم `MOBILE_EMERGENCY_MODULE_RUN.md` بيقول `11/11`؛ ده قديم ومش مصدر الحقيقة.

### 3) `pubspec.yaml`

1. **إيه هو؟** ملف تعريف الحزمة والاعتماديات.
2. **البيانات؟** `name: emergency_help`، `version: 1.0.0+1`، Dart `>=3.0.0 <4.0.0`.
3. **الحزم المهمة:** `geolocator ^13.0.1`، `geocoding ^3.0.0`، `flutter_map ^8.3.2`، `latlong2 ^0.10.1`، `firebase_core ^3.6.0`، `firebase_messaging ^15.1.3`، `flutter_local_notifications ^17.2.2`، `shared_preferences ^2.3.2`، `connectivity_plus ^6.0.3`، `url_launcher ^6.3.0`، `google_maps_flutter ^2.9.0`.
4. **الباك إند محتاجه؟** نعم عشان يعرف إيه المتاح وإيه لسه لازم يتضاف (مثل حزمة HTTP/GraphQL لو احتاجوا).
5. **الاستخدام؟** إضافة dependency جديدة للـ API/Auth لازم تُضاف هنا وبعدها `flutter pub get`.
6. **آمن؟** بحذر؛ أي تغيير لازم يتسجل في `pubspec.lock`.
7. **الفئة:** config.

### 4) `pubspec.lock`

1. **إيه هو؟** تثبيت إصدارات الحزم بالضبط.
2. **إصدارات مهمة مؤكدة من الملف نفسه:** `geolocator 13.0.4`، `geocoding 3.0.0`، `flutter_map 8.3.2`، `firebase_core 3.15.2`، `firebase_messaging 15.2.10`، `flutter_local_notifications 17.2.4`، `shared_preferences 2.5.3`، `connectivity_plus 6.1.5`، `url_launcher 6.3.2`، `google_maps_flutter 2.12.3`، `latlong2 0.10.1`.
3. **الباك إند محتاجه؟** نعم لمطابقة بيئة التشغيل وتجنب «عندي شغل وعندك مش شغل».
4. **الاستخدام؟** يتولّد من `flutter pub get`.
5. **آمن؟** ❌ لا يُحرّر يدويًا.
6. **الفئة:** config.

### 5) `android/app/src/main/AndroidManifest.xml`

1. **إيه هو؟** إعدادات أندرويد للتطبيق.
2. **الصلاحيات الموجودة:** `INTERNET`، `ACCESS_FINE_LOCATION`، `ACCESS_COARSE_LOCATION`، `POST_NOTIFICATIONS`.
3. **مقصود omit:** `CALL_PHONE` غير موجود؛ التطبيق يفتح dialer فقط ومبيعملش مكالمة.
4. **الـ queries:** dial (`tel`)، SMS (`sms`)، geo، و`PROCESS_TEXT`.
5. **الخريطة:** مفيش Google Maps API key؛ الخريطة `flutter_map` + OpenStreetMap tiles.
6. **الباك إند محتاجه؟** نعم عشان يعرف إن الـ internet مسموح، وإن مفيش network security config للـ HTTP داخل الريبو.
7. **آمن؟** بحذر. أي إضافة لـ deep links/permissions محتاجة مراجعة.
8. **الفئة:** config.

### 6) `android/app/build.gradle.kts` و`android/build.gradle.kts`

- يطبّقوا `com.google.gms.google-services`.
- `namespace` و`applicationId`: `com.example.emergency_help`.
- Java 17 + core library desugaring + `ndkVersion = "27.0.12077973"`.
- المستودعات: `google()` و`mavenCentral()`.
- الباك إند محتاج يعرف الـ application ID لو هيربط Firebase/API keys.
- التعديل بحذر؛ تغيير الـ applicationId معناه Firebase config جديد.
- الفئة: config.

### 7) `android/app/google-services.json`

- ملف ضبط Firebase موجود في المشروع.
- **لم أفتح محتواه ولم أطبع منه أي سطر.**
- مهم لتشغيل `firebase_core`/`firebase_messaging`.
- الباك إند محتاجه فقط أن يكون المشروع متوافق مع نفس Firebase project، مش محتاج يقرأ الملف في الشات.
- ❌ لا يُعدّل يدويًا ولا يُرسل مع التقرير؛ يُولّد من Firebase Console.
- الفئة: config / بيانات Firebase.

### 8) `analysis_options.yaml`

- يستخدم `flutter_lints`.
- **يستثني root `main.dart` صراحة**: «Legacy scratch copy; the real entry point is lib/main.dart».
- فيه lints مخففة عشان الحفاظ على الـ UI القديم.
- الباك إند مش محتاجه غالبًا.
- الفئة: config.

### 9) `main.dart` في جذر الريبو

- نسخة قديمة/مسودة (`legacy scratch copy`).
- فيها نفس أسماء الموديلات تقريبًا بس **مش نقطة الدخول**.
- `analysis_options.yaml` بيستثنيها.
- مفيش route إنتاجي يوصل لـ `FindNearestScreen`؛ الملف ده فيه إشارات قديمة بس.
- ❌ ما تبنيش عليه التكامل. اعتبره أرشيف.
- الفئة: legacy UI/business logic.

### 10) المستندات الموجودة

- `README.md`: نظرة عامة على المشروع (Flutter/Python/FastAPI/PostgreSQL/PostGIS/Firebase). مفيد للسياق العام، **مش مصدر عقد للموبايل**.
- `MOBILE_EMERGENCY_MODULE_HANDOVER.md`: handover إنجليزي قديم؛ بيقول إن الوحدة اترفعت على `main`، وده صح للنسخة القديمة بس، مش لأحدث كوميتاتك. كمان فيه عدّ قديم `11/11`.
- `MOBILE_EMERGENCY_MODULE_RUN.md`: دليل تشغيل سريع؛ مفيد، بس عدّ الاختبارات فيه قديم.
- `docs/MOBILE_MODULE_HANDOVER_AR.md`: هذا التقرير؛ ملف جديد غير ملتزم.

### 11) `assets/images/`

- صور/logos للـ UI مثل `nabd_logo.png` و`onboarding_bg.png`.
- الباك إند مش محتاجها.
- الفئة: UI assets.

---

## 4. شرح الـ Models والبيانات.

> كل الـ JSON أدناه **أمثلة آمنة ببيانات وهمية** للشرح فقط. هي **ليست عقد API** لأن الباك إند لسه ما بعتش عقدًا.

### أ) `LatLng`

- النوع المستخدم في الموديلات هو `google_maps_flutter.LatLng` (لأن الاستيراد غير المُسبوق بـ prefix هو Google Maps).
- ليه `latitude` و`longitude` من نوع `double` بالدرجات العشرية.
- فيه كمان `ll.LatLng` من `latlong2` لخريطة `flutter_map`، والتحويل بينهم عبر `toLl()` و`toGMap()`.
- في JSON بيطلع كـ `lat` و`lng` منفصلين، مش object اسمه `location`.

### ب) `LocationSource`

قيم التعداد كما هي في الكود:

| القيمة في الكود | التسمية في الـ UI | معناها |
|---|---|---|
| `liveGps` | `LIVE GPS` | قراءة GPS حقيقية جديدة |
| `lastKnown` | `LAST KNOWN` | آخر موقع معروف حقيقي |
| `cached` | `CACHED` | موقع مخزّن مؤقتًا |
| `simulated` | `SIMULATED` | مدخلات mock provider/إيمولاتور (`pos.isMocked`) |
| `manualSelection` | `MANUAL SELECTION` | المستخدم اختار نقطة يدويًا |
| `fallback` | `FALLBACK (not real)` | قيمة افتراضية hardcoded؛ **مش موقع حقيقي** |

نقاط مهمة جدًا للباك إند:

- `LocationResult.isReal` بيكون `true` لـ `liveGps` و`lastKnown` فقط.
- **مفيش قيمة اسمها `unavailable` أو `UNAVAILABLE` في التعداد.** لما مفيش موقع، الدالة `getCurrentPositionWithSource()` بترجع `null`. لازم الباك إند لا يفترض وجود قيمة خاصة للمفقود.
- `fallback` هي حالة ابتدائية/تسمية داخلية، مش نتيجة بتترجع لما GPS غير متاح.
- `cached.isMocked` بيخلي المصدر `simulated` حتى لو جاي من cache. الكود حافظ على تمييز الـ provenance.

### ج) `LocationResult`

الحقول:

| الحقل | النوع | المعنى |
|---|---|---|
| `position` | `LatLng` | الإحداثيات |
| `source` | `LocationSource` | تصنيف المصدر |
| `accuracyMeters` | `double?` | دقة تقريبية بالأمتار؛ nullable |
| `timestamp` | `DateTime` | وقت إنشاء النتيجة على الجهاز |

مثال توضيحي (مش ناتج `toJson()` لأن الموديل مفيش منه `toJson()` أصلاً):

```json
{
  "lat": 30.100000,
  "lng": 31.200000,
  "source": "liveGps",
  "accuracy": 12.5,
  "timestamp": "2026-11-17T10:30:00.000+02:00"
}
```

ملاحظات:

- الدقة `accuracy` من `geolocator`، وبتعرض في الـ UI بشكل `±Nm`. مفيش ضمان إنها نطاق آمن طبيًا.
- الـ `timestamp` في الكود بيتولد بـ `DateTime.now()` وقت قراءة النتيجة، **مش بالضرورة وقت الـ satellite fix نفسه**. لو الباك إند محتاج وقت الخدمة الحقيقي، لازم يتفق على حقل منفصل.
- لو المصدر `manualSelection` فـ `accuracyMeters` بيكون `null`.
- الباك إند المفروض يحافظ على `source` و`accuracy` كـ nullable، ومايحولش simulated/fallback لـ «موقع حقيقي».

### د) `EmergencySession.toJson()` — كل الحقول

| الحقل | النوع في JSON | المعنى | ملاحظة للتكامل |
|---|---|---|---|
| `id` | string | معرّف محلي؛ في `_triggerSOS()` بيتولد من `millisecondsSinceEpoch` | مش global unique. غالبًا الباك إند هيحتاج يعمل mapping أو يستبدله بـ server id. |
| `lat` | number | خط العرض الحالي للجلسة | قابل للتحديث أثناء التتبع. |
| `lng` | number | خط الطول الحالي للجلسة | قابل للتحديث أثناء التتبع. |
| `startTime` | string | `toIso8601String()` | فيه offset محلي (+02:00 مثلًا)، مش بالضرورة UTC. الاتفاق مطلوب. |
| `status` | string | `idle` / `requesting` / `active` / `resolved` | **مفيش** `assigned` / `on_the_way` / `arrived`. |
| `source` | string | إحدى قيم `LocationSource` بالاسم الإنجليزي | لازم الباك إند يقبل الأسماء دي أو يتفق على mapping. |
| `accuracy` | number or null | الدقة بالأمتار | الاسم في الدارت `accuracyMeters` بس في JSON `accuracy`. |
| `address` | string or null | عنوان/وصف من reverse geocoding أو `Address unavailable` | تقريبي؛ مش مصدر حقائق طبي. |
| `timeline` | array of strings | أحداث محلية بصيغة `ISO · event` | سجل محلي، ممكن يتحول لـ events منظّمة بعد الاتفاق. |
| `responder` | object or null | `_RespWithDist.toJson()`؛ جوّه `responder` + `distKm` | المساعد المختار محليًا/demo حاليًا. |
| `responderName` | string or null | اسم قديم مكرر للـ responder | legacy key؛ محتاج الاتفاق إذا كان الباك إند هيستخدمه ولا لا. |
| `responderDist` | string or null | مسافة بصيغة بشرية مثل `400 m` أو `1.2 km` | legacy/display-only؛ مش بديل عن `distKm`. |

مثال كامل ببيانات وهمية:

```json
{
  "id": "1763380200000",
  "lat": 30.100000,
  "lng": 31.200000,
  "startTime": "2026-11-17T10:30:00.000+02:00",
  "status": "active",
  "source": "liveGps",
  "accuracy": 12.5,
  "address": "Test Street, Test City",
  "timeline": [
    "2026-11-17T10:30:00.000+02:00 · SOS pressed · LIVE GPS · Test Street, Test City",
    "2026-11-17T10:30:01.000+02:00 · Emergency active locally — no backend delivery confirmed"
  ],
  "responder": {
    "responder": {
      "id": "responder_test_1",
      "name": "Test Responder",
      "type": "paramedic",
      "specialty": "Test Ambulance Unit",
      "lat": 30.103000,
      "lng": 31.203000,
      "address": "Test Clinic, Test City",
      "phone": "01000000000",
      "available": true
    },
    "distKm": 0.4
  },
  "responderName": "Test Responder",
  "responderDist": "400 m"
}
```

نقاط مشاكل/lenience في `fromJson()`:

- لو `source` مش معروف → بيرجع `lastKnown` بهدوء.
- لو `status` مش معروف → بيرجع `resolved` بهدوء.
- لو `responder` مش صالح → بيتجاهل.
- السجلات التالفة بتتخطى في `_loadPersistedHistory()`.
- الجلسات غير المحلولة بعد إعادة تشغيل التطبيق بتتحول لـ `resolved` مع حدث timeline بيقول إن live tracking ماكملش بعد موت الـ process.

### هـ) `Responder`

| الحقل | النوع | مطلوب في `fromJson()`؟ | ملاحظة |
|---|---|---|---|
| `id` | string | نعم، غير فاضي | من الديمو: `r1`, `near_amb_1` إلخ. الباك إند المفروض يبعت DB id. |
| `name` | string | نعم، غير فاضي | اسم للعرض. |
| `type` | string | نعم + لازم يكون واحد من `doctor`, `nurse`, `paramedic`, `volunteer` | أي قيمة تانية الموديل بيرفضها. |
| `specialty` | string | لا؛ default `''` | اختياري. |
| `lat` | number | نعم، finite | في الدارت جوّه `location`. |
| `lng` | number | نعم، finite | في الدارت جوّه `location`. |
| `address` | string | لا؛ default `''` | اختياري. |
| `phone` | string | لا؛ default `''` | أرقام الديمو مش بيانات حقيقية؛ الخصوصية مطلوبة. |
| `available` | bool | لا؛ default `true` | لو الباك إند ما بعتش الحقل، الموبايل هيظهره متاح. يفضّل يبعت صراحة. |

مثال آمن:

```json
{
  "id": "responder_test_2",
  "name": "Test Nurse",
  "type": "nurse",
  "specialty": "Test Critical Care",
  "lat": 30.110000,
  "lng": 31.210000,
  "address": "Test Hospital, Test City",
  "phone": "01100000000",
  "available": true
}
```

مشاكل/lenience:

- `_finiteDouble()` بيقبل `num` أو numeric string؛ يعني `"30.11"` هيتقبل، بس `toJson()` بيطلع number. يفضّل الباك إند يبعت numbers دايمًا.
- الموقع في الدارت `location` object، بس في JSON `lat` و`lng` على نفس المستوى. لازم الاتفاق على الشكل.
- `Responder.toJson()` مفيش فيه ETA ولا dist. المسافة موجودة بس في `_RespWithDist` كـ `distKm` جوّه حقل `responder` في الجلسة.
- `type` بالـ camelCase/lowercase الإنجليزي؛ لو DB هيخزّن `PARAMEDIC` أو `emergency_doctor` لازم mapping.

### و) models مساندة

- `AddressInfo`: بيفرّق بين عنوان unverified وverified؛ و`hasAddress` بيمنع اختراع عنوان.
- `TileLoadState`: بيتتبع فشل/تعافي بلاطات OSM؛ مفيش attribution/banner جديد.
- `_RespWithDist`: `responder` + `distKm` + `distLabel` للعرض.
- `_estimatedETA(distKm)`: `distKm / 30 * 60` دقائق — **تقدير ديمو فقط**، مش ETA من باك إند.

---

## 5. إيه اللي زميلي هيستخدمه في Backend Integration؟

> مفيش حاجة اسمها endpoint مكتوب في الكود. كل اللي أدناه وصف لـ «المطلوب يتفق عليه»، مش أسماء مسارات اخترعتها.

| # | نقطة التكامل | الموبايل الحالي (ملف/دالة) | المطلوب من الباك إند | لسه ناقص |
|---|---|---|---|---|
| 1 | إنشاء جلسة SOS | `_triggerSOS()` في `lib/main.dart`: بينشئ `EmergencySession`، id من `millisecondsSinceEpoch`، بيحفظ محليًا، يفتح dialer/SMS. مفيش HTTP. | method/path، auth، طلب فيه `lat/lng/startTime/source/accuracy/address`، رد فيه server id + status + createdAt، قواعد idempotency، كود الأخطاء وإعادة المحاولة. | أي HTTP client أو repository؛ مفيش رفع للجلسة. |
| 2 | إرسال الموقع الابتدائي | نفس `_triggerSOS()` + `getCurrentPositionWithSource()` | تحديد إذا الموقع جزء من Create Session ولا طلب منفصل؛ وحدات الدرجات؛ هل `source/accuracy/timestamp` مطلوبين؛ سياسة الـ timestamp. | مفيش إرسال. |
| 3 | تحديث الموقع أثناء التتبع | `LiveLocationService.startTracking()` يرجّع client id؛ `_emergencyTrackToken`؛ `_applyStreamedLocation()`؛ التحديث بيحصل محليًا لما المسافة > 20m ويتحفظ في History. | وتيرة الإرسال/التجميع، HTTP أو WebSocket (يقرر هو)، ترتيب الرسائل، ack، retry، offline queue، الصلاحية، أنواع `source` المقبولة. | مفيش uploader، مفيش طابور offline، مفيش ack. |
| 4 | جلب مساعدين قريبين متاحين | `_getRespondersForLocation()` بينشئ ديمو/تجميع ديناميكي حوالين المستخدم؛ `_sortedByDistance()` بيرتب بـ haversine. | معايير الاستعلام (lat/lng/radius/type/available)، شكل الاستجابة المطابق لـ `Responder`، expiry/تحديث البيانات، قواعد الخصوصية. | مفيش feed حقيقي؛ البيانات ديمو. |
| 5 | استلام assignment للمساعد | `assignedResponder` بيتحط محليًا من أقرب نتيجة ديمو. | payload/event فيه `sessionId` + `responder` + وقت الـ assignment + حالة، وطريقة الربط بـ FCM token/المستخدم. | مفيش listener ولا event handler. |
| 6 | استلام تحديثات الحالة | `EmergencyStatus`: `idle/requesting/active/resolved`؛ الإلغاء بيحط `resolved`. | أسماء الحالات الرسمية، الـ transitions المسموحة، mapping لـ UI، مصدر الحدث. | مفيش `assigned/on_the_way/arrived` في الموبايل، ومفيش استقبال. |
| 7 | ETA لو مدعوم | `_estimatedETA()` = ديمو 30 كم/س + `responderDist` للعرض. | يقرر الباك إند إذا هيبعت ETA بالثواني/الدقائق، ومتى يُعاد حسابه، ومصدره. | مفيش ETA حقيقي أو حقل له في `Responder.toJson()`. |
| 8 | إشعارات Firebase | `initializeFirebaseSafely()`، `_initBackgroundServices()`، `NotificationService`، معالجات foreground/background/cold start، channel `nabd_emergency_channel`، `getToken()` موجود. | نفس Firebase project، payload keys، تسجيل الـ token، topic/user mapping، صلاحيات الإرسال، وبعت اختبار. | الـ token **لم يُرسل لأي باك إند**؛ مفيش Test FCM فعلي؛ الـ payloads بس متسجّلة محليًا. |
| 9 | المصادقة | **لا يوجد** أي login/user id/token/header في الوحدة. | مخطط المصادقة (مثل Firebase ID token أو JWT — يقرره الباك إند)، طريقة إرفاقه بالطلبات، ربط الهوية بالجلسة، صلاحيات citizen/responder. | مفيش UI تسجيل دخول، مفيش تخزين token، مفيش استخدام لـ `getToken()`. |

### خلاصة

اللي الموبايل **بيملكه ويعرفه**: الموديلات، تصنيف الموقع، الجلسة المحلية، التاريخ، فتح dialer/SMS، الإشعارات المحلية، وتسجيل FCM payloads.

اللي الباك إند **بيملكه ومطلوب منه يحدده**: العقد، الأسماء، الأرقام، المصادقة، قاعدة البيانات، الـ feed الحقيقي، والـ push الفعلي.

---

## 6. إيه اللي لسه ناقص من ناحية Backend؟

1. **عقد API مكتوب:** base URL لكل بيئة، method/path لكل عملية، request/response schema، headers، error codes.
2. **تعريف الجلسة في DB:** هل `id` من الموبايل مقبول ولا لازم server id؟ إزاي نربط `responder` بالجلسة؟
3. **حالات موحّدة:** لازم تتنقلّ من `idle/requesting/active/resolved` لحالات الباك إند، أو تقرر الباك إند يستخدم نفس الأسماء.
4. **سياسة الموقع:** هل `source` و`accuracy` و`timestamp` بتتخزّن؟ إزاي نتعامل مع `simulated` و`manualSelection` و`null`؟
5. **Responder feed:** مصدر بيانات المساعدين المتاحين وتحديث `available` وتاريخ آخر موقع.
6. **Assignment/Events:** قناة الاستلام (push/websocket/polling) وشكل الـ payload.
7. **ETA:** يقرر الباك إند إذا هيحسبه ويبعته، ولا يفضل ديمو محلي.
8. **Firebase:** توافق المشروع، تسجيل token، من يبعت الأحداث، صلاحيات الإرسال، واختبار توصيل حقيقي.
9. **Auth:** من يقرر المخطط، وإزاي الموبايل يخزّن ويرسل الهوية.
10. **Retry/Offline/Privacy:** idempotency، طابور عندما ينقطع الإنترنت، وحدود تخزين المواقع والبيانات الشخصية.
11. **Network dev config:** مفيش cleartext HTTP config في الريبو؛ محتاج HTTPS أو إعداد محلي متفق عليه للـ emulator/device.
12. **تحديث الموديلات:** لو الباك إند هيبعت أسماء مختلفة، لازم يوافق على طبقة mapping قبل تعديل `lib/main.dart` أو إضافة نماذج جديدة.

**قرار مؤجل بوضوح:** مفيش تكامل Backend اتعمل في هذه الوحدة لحد دلوقتي، ولم يُختبر ولا كُتب عقد جديد من طرف الموبايل بمفرده.

---

## 7. إيه اللي أسلمه له بالضبط؟

### Required

| العنصر | إيه هو بالضبط | ليه محتاجه |
|---|---|---|
| رابط الريبو | `https://github.com/mazen3rby/AI-Emergency-Response-System` | عشان يعمل clone/fetch. |
| اسم الفرع | `fix/mobile-emergency-remediation` | لازم ينشر أولًا؛ غير موجود دلوقتي. |
| الـ commit | `83144174f21d7264a4013579492118809a64d706` (`8314417`) + السابق `9a24a71856046d45a42245e0e6c5974fbb515ea3` (`9a24a71`) | عشان يتأكد إنه على النسخة الصح. لو عملت commit للتغييرات غير الملتزمة، ابعت الـ hash الجديد. |
| `lib/main.dart` | كل الموديلات والخدمات و flows الـ SOS | المصدر الرئيسي للتكامل. |
| `test/mobile_emergency_module_test.dart` | 34 اختبار | عشان يفهم السلوك الحالي وما يكسرهوش. |
| `pubspec.yaml` + `pubspec.lock` | الإصدارات بالضبط | عشان بيئة التشغيل تتطابق. |
| `AndroidManifest.xml` + `build.gradle.kts` files | الصلاحيات وFirebase plugin وapplication id | عشان الإشعارات/الإنترنت/Firebase. |
| `android/app/google-services.json` | موجود محليًا | يُسلّم عبر قناة آمنة/إعداد Firebase، **مش داخل الشات أو التقرير**. |
| الموديلات | `LocationResult`, `LocationSource`, `LatLng`, `EmergencySession`, `Responder`, `_RespWithDist`, `AddressInfo`, `TileLoadState` | عشان يبني الـ mapping على الـ JSON الحقيقي. |
| الخدمات | `LiveLocationService`, `NotificationService`, `_triggerSOS()`, `_saveToHistory()`, `_loadPersistedHistory()`, `_getRespondersForLocation()`, `_estimatedETA()` | عشان يعرف أين تُحقن مكالمات الباك إند. |
| حالة التحقق | `flutter analyze`: `No issues found!` / `flutter test`: `00:01 +34: All tests passed!` / `flutter build apk --debug`: نجح | دليل إن النسخة اللي هتتسلم سليمة. |
| القيود | القائمة في القسم 9 | عشان ما يفترضش حاجات مش موجودة. |
| متطلبات الباك إند | القائمة في القسم 6 | عشان يبدأ يجهّز الـ schema. |

### Optional

| العنصر | ليه مفيد |
|---|---|
| Debug APK من `build\app\outputs\flutter-apk\app-debug.apk` | نسخة جاهزة للتجربة على جهاز حقيقي؛ اتبعها على قناة ملفات، مش ضروري في الشات. تم بناؤها محليًا بس مش مرفوعة. |
| Screenshots | توثيق UI الحالي قبل أي ربط بالباك إند. |
| Final verification report | التحقق القديم محفوظ محليًا في `C:\Users\hp\AppData\Local\Temp\opencode\gps_final\FINAL_REPORT_AR.md`؛ مفيد كمرجع، مش جزء من الريبو. |
| Logcat evidence | مفيد لو ظهرت مشاكل FCM/GPS على جهاز فعلي. |
| Mock API contract / Postman collection | **لم يتوفر بعد**؛ لو الباك إند بعت واحد يبقى هو المرجع. |

---

## 8. طريقة تشغيل المشروع.

### المتطلبات

- Flutter SDK على `PATH`. الريبو بيحدد Dart: `>=3.0.0 <4.0.0`.
- التحقق المحلي اللي اتعمل: Flutter `3.27.4`، Dart `3.6.2`، channel stable.
- Android SDK + `adb` + emulator أو جهاز حقيقي.
- `android/app/google-services.json` موجود؛ لو Firebase project مختلف، لازم يتولّد من Console. **مفيش Google Maps API key مطلوب** لأن الخريطة OSM.

### الأوامر

```powershell
cd <repo-root>
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
flutter build apk --debug
```

### النتائج المتوقعة من آخر فحص محلي

```text
flutter analyze  -> No issues found! (exit 0)
flutter test     -> 00:01 +34: All tests passed! (exit 0)
flutter build apk --debug -> √ Built build\app\outputs\flutter-apk\app-debug.apk
```

أثناء build ظهر تحذير Android x86 غير قاتل؛ الـ build نجح.

### Emulator / شبكة الباك إند

- لو الباك إند شغّال على نفس الكمبيوتر: من الـ Android emulator استخدم `10.0.2.2:<port>`.
- `localhost` جوّه الإيمولاتور معناه الإيمولاتور نفسه، مش الكمبيوتر المضيف.
- لو جهاز حقيقي: استخدم LAN IP للكمبيوتر اللي شغّال عليه الباك إند.
- الريبو **مفيش فيه network security config للـ HTTP cleartext**. استخدم HTTPS، أو اتفقوا على إعداد محلي آمن للتطوير قبل أي testing.
- صلاحية `INTERNET` موجودة في الـ manifest.

### Emulator ملاحظة من دليل التشغيل القديم

الـ run guide بيذكر AVD اسمه `Medium_Phone_API_37.0`، وبيقول إن `Pixel_6` بيحصل له crash و`Pixel_API_34` فيه kernel مفقود. ده دليل قديم؛ لو اختلف عندك، استخدم أي AVD سليم ومثبّت.

### SOS آمن أثناء التجربة

- الكود يفتح dialer/SMS/WhatsApp composers **بس**؛ مبيعملش مكالمة ولا بيرسل رسالة من تلقاء نفسه.
- `CALL_PHONE` مش موجود في الـ manifest.
- الإشعارات كلها محلية ومسمّية كـ test/local؛ مفيش ادعاء إن مساعد اتبعت.
- فضّل تجربة mock locations / بيانات اختبار فقط، وماتستخدمش أرقام حقيقية.

---

## 9. المشاكل والقيود الحالية.

1. **الفرع والكوميتات غير منشورة على GitHub.** `fix/mobile-emergency-remediation` و`9a24a71` و`8314417` مش موجودين هناك. زميلك مش هيلاقي أحدث شغلك.
2. **تغييرات غير ملتزمة:** `lib/main.dart` و`test/mobile_emergency_module_test.dart` متعدّلين محليًا (`212 insertions(+), 23 deletions(-)`). كمان هذا التقرير ملف جديد غير ملتزم.
3. **مفيش Device GPS verification حقيقي.** اللي اتعمل mocked tests؛ مفيش تأكيد على جهاز فعلي.
4. **مفيش FCM delivery test حقيقي.** الكود بيسجّل الـ payloads محليًا بس؛ `getToken()` بيرجع توكن لو Firebase جاهز بس مبيبعتهوش لأي مكان.
5. **مفيش Backend integration أصلاً.** مفيش HTTP client، مفيش endpoints، مفيش auth، مفيش repository layer.
6. **الـ responders ديمو.** `_getRespondersForLocation()` بيولّد تجميع حولين المستخدم؛ مش feed من DB.
7. **الـ ETA ديمو.** `_estimatedETA()` بيفترض 30 كم/س؛ مش نتيجة routing أو باك إند.
8. **`FindNearestScreen` مفيش له route إنتاجي** في `lib/main.dart`. الإشارات الموجودة قديمة/في الـ legacy root file.
9. **الـ root `main.dart` أرشيف** ومستبعد من analyzer؛ ما تستخدموش للتكامل.
10. **مفيش `UNAVAILABLE` في `LocationSource`.** الغياب معناه `null`، مش قيمة enum.
11. **`fromJson()` متسامح زيادة:** source/status غير المعروفين بيترجموا لـ `lastKnown`/`resolved`; ممكن يخفي مشكلة schema لو الباك إند بعت أسماء مختلفة.
12. **المستندات القديمة فيها عدّ قديم** `11/11` بينما الحالي 34 test.
13. **APK اتبنى محليًا بس مش مرفوع.** أي تسليم لازم يحدد قناة آمنة.
14. **مفيش cleartext HTTP config**؛ محتاج HTTPS أو إعداد تطوير متفق عليه.
15. **الخصوصية:** لازم ما نطبعش ولا نشارك `google-services.json` ولا أرقام/بيانات شخصية حقيقية. الأمثلة في هذا التقرير كلها وهمية.
16. **حالة SOS على جهاز حقيقي مش متجرّبة**؛ الاختبارات غطّت المنطق/managers بس. تم الحفاظ على وضع test آمن؛ مفيش مكالمة أو SMS حقيقي اتبعت.

---

## 10. رسالة جاهزة أبعتها لزميلي فيها رابط الريبو والفرع والـ commit ونقاط التسليم.

```text
السلام عليكم،

دي نقاط تسليم وحدة الطوارئ للموبايل (Flutter Android) كما هي بعد الفحص:

الريبو:
https://github.com/mazen3rby/AI-Emergency-Response-System

الفرع المطلوب:
fix/mobile-emergency-remediation

الـ commit النهائي الحالي:
83144174f21d7264a4013579492118809a64d706 (8314417)
والـ commit اللي قبله في الإصلاح:
9a24a71856046d45a42245e0e6c5974fbb515ea3 (9a24a71)

تنبيه مهم وصريح: الفرع والكوميتات دول لسه غير موجودين على GitHub حالياً. المتاح على GitHub هو main عند c7f4430 و person2/mobile-gps-sos-verified عند f4768df. هنشر الفرع بعد مراجعة التغييرات غير الملتزمة، وبعدها هبعتهالك بالـ hash النهائي. لحد ما يحصل ده، متعتمدش على إنك هتلاقي أحدث كود بالـ fetch.

الملفات الأساسية اللي هتحتاجها:
- lib/main.dart: كل الموديلات والخدمات و SOS flow
- test/mobile_emergency_module_test.dart: 34 اختبار
- pubspec.yaml + pubspec.lock: الإصدارات بالضبط
- android/app/src/main/AndroidManifest.xml: الصلاحيات والإنترنت والإشعارات
- android/app/build.gradle.kts + android/build.gradle.kts: Firebase plugin و application id
- android/app/google-services.json: موجود محلياً، هيتبعت عبر قناة آمنة مش في الشات

الموديلات/الخدمات المهمة:
LocationResult, LocationSource, EmergencySession, Responder, _RespWithDist,
LiveLocationService, NotificationService, _triggerSOS, _saveToHistory,
_getRespondersForLocation, _estimatedETA.

اللي عندي جاهز من ناحية الموبايل:
- جلسة SOS محلية + تاريخ في SharedPreferences
- تصنيف صادق للموقع (liveGps / lastKnown / cached / simulated / manualSelection / fallback)
- إشعارات محلية + FCM payload recording
- فتح dialer/SMS بدون مكالمات أو رسائل تلقائية

اللي محتاجه منك عشان التكامل:
1. عقد API مكتوب: create SOS, location update, nearby responders, assignment/status events
2. auth scheme وطريقة إرسال الهوية
3. status mapping لحالات idle/requesting/active/resolved
4. responders feed مع id/name/type/specialty/lat/lng/address/phone/available
5. FCM project/payload/token registration
6. قرار نهائي للـ ETA
7. retry/offline/idempotency وسياسة الخصوصية

حدود حالية مهمة:
- مفيش HTTP client ولا endpoints ولا auth في الكود الحالي
- المساعدين والـ ETA ديمو
- مفيش token upload للباك إند
- مفيش تجربة GPS/FCM على جهاز حقيقي
- مفيش قيمة UNAVAILABLE؛ الغياب معناه null
- التغييرات دي لسه مش ملتزمة/مش مرفوعة

التشغيل:
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
flutter build apk --debug

آخر تحقق محلي: analyze نظيف، 34/34 test نجحوا، وAPK اتبنى بنجاح.

التقرير العربي الكامل محفوظ في:
docs/MOBILE_MODULE_HANDOVER_AR.md
(ملف جديد غير ملتزم حالياً)

لو عندك schema أو Postman collection أو Firebase project مختلف، ابعته وأنا أعدّل طبقة الـ mapping في الموبايل في commit منفصل بعد موافقتك.
```

---

### ملاحظة ختامية صريحة

أنت تملك: وحدة الموبايل، الموديلات، خدمات GPS، التاريخ المحلي، الإشعارات، والاختبارات.  
زميلك يملك: عقد الباك إند، الـ DB، المصادقة، الـ feed الحقيقي، وإرسال الأحداث.  
اللي بينهم لسه مفيش: كود رفع فعلي، لأن الفرع مش منشور والكود مش متفق على عقد مع الباك إند لسه.  
ولم يتم في هذه المهمة أي commit أو push أو merge أو تغيير Git config أو كشف لأي سر.

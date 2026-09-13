<p align="center">
  <img src=".github/assets/icon.png" width="120" alt="عُبور icon">
</p>

<h1 align="center">عُبور (Oboor)</h1>

<p align="center">
  قارئ رموز QR لنظام macOS — بدون كاميرا: مكبّر يتبع مؤشرك، يمسح الشاشة نفسها، ويعرض النتيجة قبل ما يفتحها.
</p>

<p align="center">
  <a href="#العربية">العربية</a> · <a href="#english">English</a>
</p>

---

## العربية

### الغرض من التطبيق

**عُبور** يقرأ رموز QR الظاهرة على شاشتك مباشرة — سواء بصورة، صفحة ويب، أو نافذة أخرى — بدون الحاجة لكاميرا أو تصوير الشاشة يدويًا. تضغط اختصارًا واحدًا فيظهر مكبّر صغير يتبع مؤشر الماوس، تمرره فوق الرمز، ويتعرف عليه عُبور فورًا عبر Vision.

قبل ما يفتح أي شيء، يعرض عُبور معاينة لمحتوى الرمز — رابط، شبكة واي فاي، جهة اتصال، حدث تقويم، رقم هاتف، أو نص عادي — وأنت تقرر: تفتحه، تنسخه، أو تتجاهله. يحتفظ أيضًا بسجل لآخر الرموز الممسوحة يمكن الرجوع له من قائمة شريط القوائم.

مبني كملف Swift واحد بدون Xcode، ويعمل من شريط القوائم بدون أيقونة Dock. الواجهة تدعم العربية والإنجليزية، قابلة للتبديل من الإعدادات.

### الاستخدام

| الإجراء | النتيجة |
|---|---|
| `⌘⇧O` | تشغيل/إيقاف وضع المسح (قابل للتغيير من الإعدادات) |
| المكبّر يتبع مؤشرك تلقائيًا | مرّره فوق رمز QR فيتعرف عليه فورًا ويعرض معاينة لمحتواه |
| `Space` مسافة | تثبيت المكبّر بمكانه (يتلوّن برتقاليًا) — ضغطة ثانية تعيده يتبع المؤشر |
| `Esc` | إلغاء وضع المسح |
| نقرة على نتيجة رابط | فتحه بالمتصفح — أو بتطبيق التواصل الاجتماعي المناسب إن وُجد |
| نتيجة واي فاي | فتح إعدادات الواي فاي، مع نسخ أو إظهار كلمة المرور |
| نتيجة جهة اتصال أو حدث | إضافتها مباشرة لجهات الاتصال أو التقويم |
| من قائمة شريط القوائم | مسح فوري، فتح السجل، الإعدادات، أو الإنهاء |

#### الإعدادات
اختصار تشغيل المسح (قابل للتسجيل)، لغة الواجهة (عربي/إنجليزي)، والتشغيل التلقائي عند بدء الماك.

#### الصلاحيات
يحتاج **تسجيل الشاشة (Screen Recording)** لالتقاط ما تحت المكبّر أثناء المسح — لا تصوير مستمر ولا حفظ، فقط أثناء المسح. كذلك **جهات الاتصال** و**التقويم** عند اختيارك إضافة جهة اتصال أو حدث من رمز ممسوح — لا وصول بدون طلبك المباشر.

### البناء من المصدر

```bash
git clone https://github.com/omaralmutairi-afk/Oboor.git
cd Oboor
./build.sh   # يبني Oboor.app ويثبّته على سطح المكتب، موقّعًا محليًا
```

يحتاج macOS 14 فأعلى. لا يوجد مشروع Xcode — `build.sh` يستخدم `swiftc` مباشرة.

### الحالة

مكتمل، ومرّ بعدة مراجعات كود.

---

## English

### Purpose

**Oboor** reads QR codes shown directly on your screen — in an image, a web page, or any other window — with no camera and no manual screenshotting. One hotkey brings up a small magnifier that follows your cursor; hover it over the code and Oboor recognizes it instantly via Vision.

Before opening anything, Oboor shows a preview of the code's content — a link, Wi-Fi network, contact, calendar event, phone number, or plain text — and you decide: open it, copy it, or dismiss it. It also keeps a history of recently scanned codes, reachable from the menu bar.

Built as a single Swift file with no Xcode project, running from the menu bar with no Dock icon. The interface supports both Arabic and English, switchable from Settings.

### Usage

| Action | Result |
|---|---|
| `⌘⇧O` | Start/stop scan mode (changeable in Settings) |
| Magnifier follows your cursor automatically | Hover it over a QR code and it's recognized instantly, showing a preview of its content |
| `Space` | Pins the magnifier in place (turns orange) — press again to resume following the cursor |
| `Esc` | Cancel scan mode |
| Click a link result | Opens it in the browser — or the matching social app if one applies |
| Wi-Fi result | Opens Wi-Fi settings, with the password copyable or revealable |
| Contact or event result | Adds it directly to Contacts or Calendar |
| From the menu bar | Scan now, open history, Settings, or quit |

#### Settings
A recordable scan hotkey, interface language (Arabic/English), and launch at startup.

#### Permissions
Requires **Screen Recording** to capture what's under the magnifier while scanning — no continuous capture and nothing saved, only while actively scanning. Also requests **Contacts** and **Calendar** access, but only when you choose to add a contact or event from a scanned code — no access without your direct action.

### Building from source

```bash
git clone https://github.com/omaralmutairi-afk/Oboor.git
cd Oboor
./build.sh   # builds Oboor.app and installs it to the Desktop, locally signed
```

Requires macOS 14 or later. No Xcode project — `build.sh` calls `swiftc` directly.

### Status

Feature-complete, and has been through several code review passes.

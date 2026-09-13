import Cocoa
import Carbon.HIToolbox
import ServiceManagement
import Vision
import WebKit
import Contacts
import EventKit
import ScreenCaptureKit

extension Notification.Name {
    static let oboorSettingsChanged = Notification.Name("oboorSettingsChanged")
    static let oboorHistoryChanged = Notification.Name("oboorHistoryChanged")
}

// MARK: - Settings

/// Wraps SMAppService so "launch at login" is a real login item visible in
/// System Settings ▸ General ▸ Login Items — same approach as Naqla/Laqta.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Oboor] LoginItem toggle failed: \(error)")
            fflush(stdout)
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case ar, en
    var displayName: String { self == .ar ? "العربية" : "English" }
    var layoutDirection: NSUserInterfaceLayoutDirection { self == .ar ? .rightToLeft : .leftToRight }
}

final class SettingsStore {
    static let shared = SettingsStore()
    private let d = UserDefaults.standard

    private enum Key {
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let language = "language"
        static let pinKeyCode = "pinKeyCode"
        static let pinKeyModifiers = "pinKeyModifiers"
        static let privateBrowserID = "privateBrowserID"
    }

    private init() {
        d.register(defaults: [
            Key.hotKeyCode: Int(kVK_ANSI_O),
            Key.hotKeyModifiers: Int(cmdKey | shiftKey),
            Key.pinKeyCode: Int(kVK_ANSI_P),
            Key.pinKeyModifiers: 0,
        ])
    }

    private func changed() {
        NotificationCenter.default.post(name: .oboorSettingsChanged, object: nil)
    }

    var hotKeyCode: UInt32 { UInt32(d.integer(forKey: Key.hotKeyCode)) }
    var hotKeyModifiers: UInt32 { UInt32(d.integer(forKey: Key.hotKeyModifiers)) }
    var pinKeyCode: UInt32 { UInt32(d.integer(forKey: Key.pinKeyCode)) }
    var pinKeyModifiers: UInt32 { UInt32(d.integer(forKey: Key.pinKeyModifiers)) }

    // Code and modifiers are written together, then announced once — two
    // separate notifications briefly registered a half-updated combo.
    func setHotKey(code: UInt32, modifiers: UInt32) {
        d.set(Int(code), forKey: Key.hotKeyCode)
        d.set(Int(modifiers), forKey: Key.hotKeyModifiers)
        changed()
    }

    func setPinKey(code: UInt32, modifiers: UInt32) {
        d.set(Int(code), forKey: Key.pinKeyCode)
        d.set(Int(modifiers), forKey: Key.pinKeyModifiers)
        changed()
    }

    /// Bundle ID of the browser chosen for private opening; nil means automatic.
    var privateBrowserID: String? {
        get { d.string(forKey: Key.privateBrowserID) }
        set { d.set(newValue, forKey: Key.privateBrowserID); changed() }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: d.string(forKey: Key.language) ?? "") ?? .ar }
        set { d.set(newValue.rawValue, forKey: Key.language); changed() }
    }

    /// A clipboard-manager-style "enable once on first run" — a background
    /// scanner tool nobody remembers to switch on manually is useless.
    func enableLoginItemOnFirstRun() {
        let key = "didEnableLoginItemOnce"
        guard !d.bool(forKey: key) else { return }
        d.set(true, forKey: key)
        LoginItem.setEnabled(true)
    }
}

/// Every user-facing string in one place, since this single-file app has no
/// Xcode asset pipeline for real .lproj/NSLocalizedString support.
enum L {
    enum Key {
        case statusItemAccessibility, scanNowMenuItem, settingsMenuItem, quitMenuItem,
             settingsWindowTitle, hotkeyRow, languageRow, launchAtLoginCheckbox, pressCombo, pinKeyRow, privateBrowserRow, privateBrowserAutomatic,
             lensCaption, lensCaptionPinned, screenRecordingAlertTitle, screenRecordingAlertBody,
             screenRecordingAlertOpenSettings, screenRecordingAlertCancel,
             previewTitle, openInBrowser, openPrivately, openPrivatelyIn, copyLink, copied,
             openInApp, openInAppStore, loadingAppStore,
             wifiCardTitle, wifiJoin, wifiCopyPassword, wifiOpenSettings, wifiHiddenBadge,
             contactCardTitle, contactAdd, contactAdded, contactAddFailed, contactNoName,
             calendarCardTitle, calendarAdd, calendarAdded, calendarAddFailed, calendarNoTitle,
             emailCardTitle, emailOpen, phoneCardTitle, phoneCall, phoneCopy,
             smsCardTitle, smsOpen, geoCardTitle, geoOpen, textCardTitle, copyText,
             genericOpenFailed, close,
             wifiShowPassword, wifiHidePassword,
             fieldName, fieldPhone, fieldEmail, fieldOrg, fieldPassword,
             fieldTitle, fieldLocation, fieldStart, fieldEnd, fieldCoordinates, fieldMessage, fieldLink,
             historyMenuItem, historyWindowTitle, historyEmpty, historyClear
    }

    private static let table: [Key: (ar: String, en: String)] = [
        .statusItemAccessibility: ("عُبور", "Oboor"),
        .scanNowMenuItem: ("امسح رمز الآن", "Scan a Code Now"),
        .settingsMenuItem: ("الإعدادات…", "Settings…"),
        .quitMenuItem: ("إنهاء عُبور", "Quit Oboor"),
        .settingsWindowTitle: ("إعدادات عُبور", "Oboor Settings"),
        .hotkeyRow: ("اختصار المسح", "Scan shortcut"),
        .languageRow: ("اللغة", "Language"),
        .launchAtLoginCheckbox: ("تشغيل عُبور تلقائيًا عند بدء تشغيل الماك", "Launch Oboor automatically at startup"),
        .pressCombo: ("اضغط الاختصار…", "Press a shortcut…"),
        .pinKeyRow: ("اختصار التثبيت أثناء المسح", "Pin shortcut while scanning"),
        .privateBrowserRow: ("المتصفح للفتح الخفي", "Browser for private opening"),
        .privateBrowserAutomatic: ("تلقائي", "Automatic"),
        .lensCaption: ("%@ للتثبيت · Esc للإلغاء", "%@ to pin · Esc to cancel"),
        .lensCaptionPinned: ("مثبّت — %@ للمتابعة · Esc للإلغاء", "Pinned — %@: follow · Esc: cancel"),
        .screenRecordingAlertTitle: ("عُبور يحتاج صلاحية تسجيل الشاشة", "Oboor needs Screen Recording access"),
        .screenRecordingAlertBody: ("عشان يقرأ رمز QR من شاشتك، فعّل الصلاحية من إعدادات النظام ثم أعد فتح عُبور.", "To read a QR code from your screen, grant the permission in System Settings, then relaunch Oboor."),
        .screenRecordingAlertOpenSettings: ("فتح الإعدادات", "Open Settings"),
        .screenRecordingAlertCancel: ("إلغاء", "Cancel"),
        .previewTitle: ("معاينة — عُبور", "Preview — Oboor"),
        .openInBrowser: ("فتح في المتصفح", "Open in Browser"),
        .openPrivately: ("فتح خفي", "Open Privately"),
        .openPrivatelyIn: ("فتح خفي في %@", "Open Privately in %@"),
        .copyLink: ("نسخ الرابط", "Copy Link"),
        .copied: ("تم النسخ ✓", "Copied ✓"),
        .openInApp: ("فتح في التطبيق", "Open in App"),
        .openInAppStore: ("فتح في App Store", "Open in App Store"),
        .loadingAppStore: ("جاري التحميل…", "Loading…"),
        .wifiCardTitle: ("شبكة واي فاي", "Wi-Fi Network"),
        .wifiJoin: ("فتح إعدادات الواي فاي", "Open Wi-Fi Settings"),
        .wifiCopyPassword: ("نسخ كلمة المرور", "Copy Password"),
        .wifiOpenSettings: ("فتح إعدادات الواي فاي", "Open Wi-Fi Settings"),
        .wifiHiddenBadge: ("شبكة مخفية", "Hidden network"),
        .wifiShowPassword: ("إظهار كلمة المرور", "Show Password"),
        .wifiHidePassword: ("إخفاء كلمة المرور", "Hide Password"),
        .fieldName: ("الاسم", "Name"),
        .fieldPhone: ("الهاتف", "Phone"),
        .fieldEmail: ("البريد الإلكتروني", "Email"),
        .fieldOrg: ("الجهة", "Organization"),
        .fieldPassword: ("كلمة المرور", "Password"),
        .fieldTitle: ("العنوان", "Title"),
        .fieldLocation: ("الموقع", "Location"),
        .fieldStart: ("البداية", "Start"),
        .fieldEnd: ("النهاية", "End"),
        .fieldCoordinates: ("الإحداثيات", "Coordinates"),
        .fieldMessage: ("الرسالة", "Message"),
        .fieldLink: ("الرابط", "Link"),
        .historyMenuItem: ("السجل الأخير…", "Recent History…"),
        .historyWindowTitle: ("آخر الروابط — عُبور", "Recent Links — Oboor"),
        .historyEmpty: ("لا يوجد سجل بعد", "No history yet"),
        .historyClear: ("مسح السجل", "Clear History"),
        .contactCardTitle: ("جهة اتصال", "Contact"),
        .contactAdd: ("إضافة إلى جهات الاتصال", "Add to Contacts"),
        .contactAdded: ("تمت الإضافة ✓", "Added ✓"),
        .contactAddFailed: ("تعذّرت الإضافة", "Couldn't add contact"),
        .contactNoName: ("جهة اتصال بدون اسم", "Unnamed contact"),
        .calendarCardTitle: ("حدث تقويم", "Calendar Event"),
        .calendarAdd: ("إضافة إلى التقويم", "Add to Calendar"),
        .calendarAdded: ("تمت الإضافة ✓", "Added ✓"),
        .calendarAddFailed: ("تعذّرت الإضافة", "Couldn't add event"),
        .calendarNoTitle: ("حدث بدون عنوان", "Untitled event"),
        .emailCardTitle: ("عنوان بريد إلكتروني", "Email Address"),
        .emailOpen: ("فتح في البريد", "Open in Mail"),
        .phoneCardTitle: ("رقم هاتف", "Phone Number"),
        .phoneCall: ("اتصال", "Call"),
        .phoneCopy: ("نسخ الرقم", "Copy Number"),
        .smsCardTitle: ("رسالة نصية", "Text Message"),
        .smsOpen: ("فتح في الرسائل", "Open in Messages"),
        .geoCardTitle: ("موقع جغرافي", "Location"),
        .geoOpen: ("فتح في الخرائط", "Open in Maps"),
        .textCardTitle: ("نص", "Text"),
        .copyText: ("نسخ النص", "Copy Text"),
        .genericOpenFailed: ("تعذّر الفتح", "Couldn't open"),
        .close: ("إغلاق", "Close"),
    ]

    static func t(_ key: Key) -> String {
        let pair = table[key]!
        return SettingsStore.shared.language == .ar ? pair.ar : pair.en
    }
}

// MARK: - Recent history

struct HistoryEntry: Codable {
    let url: String
    let title: String
    let date: Date
}

/// The last few links actually opened through a Preview window's buttons —
/// deliberately not every scanned code, since "history" here means "where
/// did I go," not "what did I scan."
final class HistoryStore {
    static let shared = HistoryStore()
    private static let key = "recentHistory"
    private static let maxCount = 5

    private(set) var entries: [HistoryEntry] = []

    private init() { load() }

    func record(url: String, title: String) {
        entries.insert(HistoryEntry(url: url, title: title, date: Date()), at: 0)
        if entries.count > Self.maxCount { entries.removeLast(entries.count - Self.maxCount) }
        save()
        NotificationCenter.default.post(name: .oboorHistoryChanged, object: nil)
    }

    func clear() {
        entries = []
        save()
        NotificationCenter.default.post(name: .oboorHistoryChanged, object: nil)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

// MARK: - Global hotkey (Carbon)

private var hotKeyHandlers: [UInt32: () -> Void] = [:]
private var hotKeyEventHandlerInstalled = false

private func hotKeyEventHandler(_ nextHandler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return status }
    hotKeyHandlers[hotKeyID.id]?()
    return noErr
}

/// One place for the IDs, since `hotKeyHandlers` is keyed by them and a
/// duplicate would silently replace another hotkey's handler.
enum HotKeyID: UInt32 {
    case scan = 1, lensEscape, lensPin
}

final class GlobalHotKey {
    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?

    init(_ id: HotKeyID) { self.id = id.rawValue }

    func register(keyCode: UInt32, modifiers: UInt32, toggle: @escaping () -> Void) {
        if !hotKeyEventHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &eventType, nil, nil)
            hotKeyEventHandlerInstalled = true
        }
        unregister()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F42524B), id: id) // 'OBRK'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            print("[Oboor] RegisterEventHotKey(key: \(keyCode), mods: \(modifiers)) failed: \(status)")
            fflush(stdout)
            return
        }
        hotKeyHandlers[id] = toggle
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        hotKeyHandlers[id] = nil
    }
}

/// A click-to-record shortcut field, same interaction as System Settings'
/// own shortcut recorders — lifted from Naqla's KeyRecorderView.
final class KeyRecorderView: NSView {
    /// Returns false to reject the combo (e.g. it collides with the other
    /// shortcut); the recorder then beeps and keeps recording.
    var onChange: ((UInt32, UInt32) -> Bool)?

    private var keyCode: UInt32
    private var modifiers: UInt32
    private let requiresModifier: Bool
    private var isRecording = false { didSet { refresh() } }
    private let label = NSTextField(labelWithString: "")

    private static let keyNames: [UInt32: String] = {
        [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
            UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F", UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
            UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
            UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R", UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
            UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z", UInt32(kVK_Space): "Space",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2", UInt32(kVK_ANSI_3): "3",
            UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5", UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7",
            UInt32(kVK_ANSI_8): "8", UInt32(kVK_ANSI_9): "9",
        ]
    }()

    init(keyCode: UInt32, modifiers: UInt32, requiresModifier: Bool = true) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.requiresModifier = requiresModifier
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6

        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 130).isActive = true
        heightAnchor.constraint(equalToConstant: 24).isActive = true

        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(startRecording))
        addGestureRecognizer(click)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    @objc private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        if event.keyCode == UInt16(kVK_Escape) { isRecording = false; return }
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let code = UInt32(event.keyCode)
        // Keys missing from keyNames would display as "?".
        guard Self.keyNames[code] != nil, !(requiresModifier && mods.isEmpty) else { NSSound.beep(); return }
        let newModifiers = Self.carbonModifiers(from: mods)
        guard onChange?(code, newModifiers) ?? true else { NSSound.beep(); return }
        keyCode = code
        modifiers = newModifiers
        isRecording = false
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    private func refresh() {
        layer?.borderWidth = 1
        layer?.borderColor = (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        layer?.backgroundColor = (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).cgColor
        label.stringValue = isRecording ? L.t(.pressCombo) : Self.symbolString(keyCode: keyCode, modifiers: modifiers)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }

    static func symbolString(keyCode: UInt32, modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += keyNames[keyCode] ?? "?"
        return s
    }
}

// MARK: - QR payload classification

enum PayloadKind {
    case url(URL)
    case appStore(URL)
    case social(URL, appScheme: URL?)
    case wifi(ssid: String, password: String?, hidden: Bool)
    case contact(name: String?, phone: String?, email: String?, org: String?)
    case email(String)
    case phone(String)
    case sms(number: String, body: String?)
    case geo(coordinates: String, mapsURL: URL)
    case calendarEvent(title: String?, location: String?, start: Date?, end: Date?)
    case text(String)
}

struct ParsedPayload {
    let raw: String
    let kind: PayloadKind
}

enum PayloadClassifier {
    static func classify(_ raw: String) -> ParsedPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()

        if upper.hasPrefix("WIFI:") { return ParsedPayload(raw: raw, kind: classifyWiFi(trimmed)) }
        if upper.hasPrefix("BEGIN:VCARD") { return ParsedPayload(raw: raw, kind: classifyVCard(trimmed)) }
        if upper.hasPrefix("MECARD:") { return ParsedPayload(raw: raw, kind: classifyMeCard(trimmed)) }
        if upper.contains("BEGIN:VEVENT") { return ParsedPayload(raw: raw, kind: classifyVEvent(trimmed)) }
        if upper.hasPrefix("MAILTO:") { return ParsedPayload(raw: raw, kind: .email(String(trimmed.dropFirst(7)))) }
        if upper.hasPrefix("TEL:") { return ParsedPayload(raw: raw, kind: .phone(String(trimmed.dropFirst(4)))) }
        if upper.hasPrefix("SMSTO:") || upper.hasPrefix("SMS:") {
            return ParsedPayload(raw: raw, kind: classifySMS(trimmed))
        }
        if upper.hasPrefix("GEO:") {
            // geo:lat,lon may carry ;u=… or ?q=… suffixes that don't belong in ll=.
            let coords = String(trimmed.dropFirst(4).prefix { $0 != "?" && $0 != ";" }.filter { !$0.isWhitespace })
            if let mapsURL = URL(string: "http://maps.apple.com/?ll=\(coords)") {
                return ParsedPayload(raw: raw, kind: .geo(coordinates: coords, mapsURL: mapsURL))
            }
        }
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme.hasPrefix("http"), let host = url.host?.lowercased() {
            if host.contains("apps.apple.com") || host.contains("itunes.apple.com") {
                return ParsedPayload(raw: raw, kind: .appStore(url))
            }
            let socialHosts = ["instagram.com", "twitter.com", "x.com", "tiktok.com", "facebook.com",
                                "linkedin.com", "snapchat.com", "threads.net", "youtube.com", "wa.me",
                                "whatsapp.com", "t.me"]
            if socialHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                return ParsedPayload(raw: raw, kind: .social(url, appScheme: socialAppScheme(for: url, host: host)))
            }
            return ParsedPayload(raw: raw, kind: .url(url))
        }
        return ParsedPayload(raw: raw, kind: .text(trimmed))
    }

    /// Splits WIFI:/MECARD: content into KEY/value fields on unescaped `;`,
    /// honoring `\;` `\:` `\,` `\\` `\"` — Wi-Fi passwords routinely contain
    /// `;` or `:`, and a plain split cut them short.
    static func escapedFields(_ content: Substring) -> [(key: String, value: String)] {
        var segments: [String] = []
        var current = ""
        var escaping = false
        for ch in content {
            if escaping { current.append("\\"); current.append(ch); escaping = false }
            else if ch == "\\" { escaping = true }
            else if ch == ";" { segments.append(current); current = "" }
            else { current.append(ch) }
        }
        if !current.isEmpty { segments.append(current) }

        return segments.compactMap { segment in
            guard let colon = segment.firstIndex(of: ":") else { return nil }
            var rawValue = String(segment[segment.index(after: colon)...])
            if rawValue.count >= 2, rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), !rawValue.hasSuffix("\\\"") {
                rawValue = String(rawValue.dropFirst().dropLast())
            }
            var value = ""
            var escaping = false
            for ch in rawValue {
                if escaping { value.append(ch); escaping = false }
                else if ch == "\\" { escaping = true }
                else { value.append(ch) }
            }
            return (segment[..<colon].uppercased(), value)
        }
    }

    /// vCard/iCalendar TEXT escaping: `\,` `\;` `\\` and `\n`.
    static func unescapeText(_ s: String) -> String {
        var out = ""
        var escaping = false
        for ch in s {
            if escaping { out.append(ch == "n" || ch == "N" ? "\n" : ch); escaping = false }
            else if ch == "\\" { escaping = true }
            else { out.append(ch) }
        }
        return out
    }

    private static func classifyWiFi(_ raw: String) -> PayloadKind {
        var ssid = ""
        var password: String?
        var hidden = false
        for field in escapedFields(raw.dropFirst("WIFI:".count)) {
            switch field.key {
            case "S": ssid = field.value
            case "P": password = field.value.isEmpty ? nil : field.value
            case "H": hidden = field.value.lowercased() == "true"
            default: break
            }
        }
        return .wifi(ssid: ssid, password: password, hidden: hidden)
    }

    private static func classifyVCard(_ raw: String) -> PayloadKind {
        var name: String?, phone: String?, email: String?, org: String?
        for line in raw.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].uppercased()
            let value = unescapeText(parts[1].trimmingCharacters(in: .whitespaces))
            if key.hasPrefix("FN") { name = value }
            else if key == "N" || key.hasPrefix("N;") {
                // N is "Last;First;…" — only a fallback for a card without FN.
                guard name == nil else { continue }
                let components = parts[1].split(separator: ";", omittingEmptySubsequences: false)
                    .map { unescapeText($0.trimmingCharacters(in: .whitespaces)) }
                let joined = [components.count > 1 ? components[1] : "", components.first ?? ""]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                if !joined.isEmpty { name = joined }
            }
            else if key.hasPrefix("TEL"), phone == nil { phone = value }
            else if key.hasPrefix("EMAIL"), email == nil { email = value }
            else if key.hasPrefix("ORG") { org = value }
        }
        return .contact(name: name, phone: phone, email: email, org: org)
    }

    private static func classifyMeCard(_ raw: String) -> PayloadKind {
        var name: String?, phone: String?, email: String?, org: String?
        for field in escapedFields(raw.dropFirst("MECARD:".count)) {
            switch field.key {
            case "N":
                // MECARD's N is "Last,First"; ContactSaver expects "First Last".
                let parts = field.value.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                name = parts.count == 2 ? "\(parts[1]) \(parts[0])" : field.value
            case "TEL": if phone == nil { phone = field.value }
            case "EMAIL": if email == nil { email = field.value }
            case "ORG": org = field.value
            default: break
            }
        }
        return .contact(name: name, phone: phone, email: email, org: org)
    }

    /// SMSTO:<number>:<body> (what most QR generators emit) or
    /// sms:<number>?body=<body>. Messages on macOS doesn't handle SMSTO:
    /// URLs at all, so the parts are kept and an sms: URL is rebuilt later.
    private static func classifySMS(_ raw: String) -> PayloadKind {
        let content = String(raw.drop { $0 != ":" }.dropFirst())
        if raw.uppercased().hasPrefix("SMSTO:") {
            let parts = content.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            let body = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
            return .sms(number: parts[0], body: body)
        }
        let parts = content.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        var body: String?
        if parts.count > 1 {
            for pair in parts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2, kv[0].lowercased() == "body" {
                    body = kv[1].removingPercentEncoding ?? kv[1]
                }
            }
        }
        return .sms(number: parts[0], body: body)
    }

    private static func classifyVEvent(_ raw: String) -> PayloadKind {
        var title: String?, location: String?, start: Date?, end: Date?
        for line in raw.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].uppercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("SUMMARY") { title = unescapeText(value) }
            else if key.hasPrefix("LOCATION") { location = unescapeText(value) }
            else if key.hasPrefix("DTSTART") { start = parseICalDate(value, params: parts[0]) }
            else if key.hasPrefix("DTEND") { end = parseICalDate(value, params: parts[0]) }
        }
        return .calendarEvent(title: title, location: location, start: start, end: end)
    }

    /// A trailing Z means UTC, `;TZID=` names the zone, and anything else is
    /// floating local time — reading every value as UTC shifted local events
    /// by the user's UTC offset. POSIX locale + Gregorian, because a device
    /// set to an Islamic-calendar region otherwise misreads "2026…" years.
    static func parseICalDate(_ value: String, params: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        var text = value
        if text.uppercased().hasSuffix("Z") {
            text.removeLast()
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else if let range = params.range(of: "TZID=", options: .caseInsensitive) {
            let zone = params[range.upperBound...].prefix { $0 != ";" }.replacingOccurrences(of: "\"", with: "")
            formatter.timeZone = TimeZone(identifier: zone) ?? .current
        } else {
            formatter.timeZone = .current
        }
        switch text.count {
        case 8: formatter.dateFormat = "yyyyMMdd"
        case 13: formatter.dateFormat = "yyyyMMdd'T'HHmm"
        default: formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        }
        return formatter.date(from: text)
    }

    /// First path segments that are features, not usernames — without this,
    /// "Open in App" on a post link (instagram.com/p/…, x.com/i/…) opened a
    /// nonexistent profile named "p" or "i".
    private static let nonProfilePaths: Set<String> = [
        "p", "reel", "reels", "tv", "stories", "explore", "accounts", "direct",
        "i", "intent", "home", "search", "hashtag", "settings", "messages", "notifications",
        "share", "sharer", "sharer.php", "groups", "events", "watch", "pages", "marketplace",
        "story.php", "permalink.php", "photo", "photo.php", "login",
        "joinchat", "c", "s", "addstickers", "proxy",
    ]

    private static func socialAppScheme(for url: URL, host: String) -> URL? {
        let parts = url.path.split(separator: "/").map(String.init)
        let username = parts.count == 1 && !parts[0].hasPrefix("+") && !nonProfilePaths.contains(parts[0].lowercased())
            ? parts[0] : nil
        if host.contains("instagram.com"), let u = username {
            return URL(string: "instagram://user?username=\(u)")
        }
        if host == "twitter.com" || host == "x.com" || host.hasSuffix(".twitter.com") || host.hasSuffix(".x.com"), let u = username {
            return URL(string: "twitter://user?screen_name=\(u)")
        }
        if host.contains("facebook.com"), parts == ["profile.php"],
           let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value,
           !id.isEmpty, id.allSatisfy(\.isNumber) {
            return URL(string: "fb://profile/\(id)")
        }
        // WhatsApp's Mac app claims no associated domains, so universal
        // links can't reach it — its own whatsapp:// scheme is the only way
        // in. Channel links (whatsapp.com/channel/<id>) map onto that
        // scheme's channel route; wa.me/<digits> maps to a chat. Any other
        // wa.me path (wa.me/c/…, wa.me/message/…) isn't a phone number and
        // must not be turned into a bogus send?phone= link.
        if host.contains("whatsapp.com") || host.contains("wa.me") {
            let parts = url.path.split(separator: "/").map(String.init)
            if parts.count >= 2, parts[0] == "channel" {
                return URL(string: "whatsapp://channel/\(parts[1])")
            }
            if host.contains("wa.me"), parts.count == 1, parts[0].allSatisfy(\.isNumber) {
                return URL(string: "whatsapp://send?phone=\(parts[0])")
            }
            return nil
        }
        if host.contains("t.me"), let u = username {
            return URL(string: "tg://resolve?domain=\(u)")
        }
        if host.contains("facebook.com"), let u = username {
            return URL(string: "fb://profile/\(u)")
        }
        return nil
    }
}

// MARK: - Screen capture + QR detection

enum ScreenCapturePermission {
    static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    static func request() {
        CGRequestScreenCaptureAccess()
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum QRDetector {
    /// Captures everything on screen below `windowID` within `rect` (both in
    /// Cocoa screen coordinates) and looks for a QR payload. Deliberately
    /// excludes the lens window itself from the capture so the frame's own
    /// chrome never gets mistaken for content.
    /// `primaryScreenMaxY` and `scale` come from the main thread, since this
    /// runs detached and NSScreen/NSWindow aren't safe to touch from here.
    static func scan(rect: NSRect, primaryScreenMaxY: CGFloat, scale: CGFloat, excludingWindowID windowID: CGWindowID) async -> String? {
        // Cocoa's global space is bottom-left based on the primary screen;
        // ScreenCaptureKit's is top-left based on that same screen.
        let globalRect = CGRect(x: rect.origin.x, y: primaryScreenMaxY - rect.origin.y - rect.height, width: rect.width, height: rect.height)

        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else { return nil }
        let center = CGPoint(x: globalRect.midX, y: globalRect.midY)
        guard let display = content.displays.first(where: { $0.frame.contains(center) })
                ?? content.displays.first(where: { $0.frame.intersects(globalRect) }) else { return nil }
        // sourceRect is relative to the chosen display (not global, which
        // captured the wrong area on a secondary monitor) and clipped to it,
        // since the lens can hang off a screen edge.
        let visible = globalRect.intersection(display.frame)
        guard !visible.isNull, visible.width > 1, visible.height > 1 else { return nil }
        let sourceRect = visible.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)

        let excludedWindows = content.windows.filter { $0.windowID == windowID }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let config = SCStreamConfiguration()
        // Pixels, not points: a 1x capture on Retina halved the detail Vision
        // gets, which is what small embedded codes need most.
        config.width = max(1, Int(sourceRect.width * scale))
        config.height = max(1, Int(sourceRect.height * scale))
        config.sourceRect = sourceRect
        config.showsCursor = false

        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else {
            return nil
        }
        guard image.width > 1, image.height > 1 else { return nil }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        return request.results?.first?.payloadStringValue
    }
}

// MARK: - Lens overlay

/// Draws the magnifier-style scan frame: four corner brackets over an
/// otherwise fully transparent view, so the capture underneath is never
/// obscured by the frame's own chrome.
final class LensFrameView: NSView {
    var isPinned = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()

        let accent = isPinned
            ? NSColor(calibratedRed: 0.95, green: 0.65, blue: 0.15, alpha: 1.0)
            : NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.72, alpha: 1.0)
        let inset: CGFloat = 6
        let armLength: CGFloat = 26
        let lineWidth: CGFloat = 4
        let r = bounds.insetBy(dx: inset, dy: inset)

        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round

        // Bottom-left
        path.move(to: NSPoint(x: r.minX, y: r.minY + armLength))
        path.line(to: NSPoint(x: r.minX, y: r.minY))
        path.line(to: NSPoint(x: r.minX + armLength, y: r.minY))
        // Bottom-right
        path.move(to: NSPoint(x: r.maxX - armLength, y: r.minY))
        path.line(to: NSPoint(x: r.maxX, y: r.minY))
        path.line(to: NSPoint(x: r.maxX, y: r.minY + armLength))
        // Top-right
        path.move(to: NSPoint(x: r.maxX, y: r.maxY - armLength))
        path.line(to: NSPoint(x: r.maxX, y: r.maxY))
        path.line(to: NSPoint(x: r.maxX - armLength, y: r.maxY))
        // Top-left
        path.move(to: NSPoint(x: r.minX + armLength, y: r.maxY))
        path.line(to: NSPoint(x: r.minX, y: r.maxY))
        path.line(to: NSPoint(x: r.minX, y: r.maxY - armLength))

        accent.setStroke()
        path.stroke()
    }
}

final class LensWindowController: NSWindowController {
    private var scanTimer: Timer?
    private var followTimer: Timer?
    private let escapeHotKey = GlobalHotKey(.lensEscape)
    private let pinHotKey = GlobalHotKey(.lensPin)
    private var frameView: LensFrameView!
    private var caption: NSTextField!
    private var isPinned = false {
        didSet {
            frameView.isPinned = isPinned
            caption.stringValue = Self.captionText(pinned: isPinned)
        }
    }
    private var isFinished = false
    var onFound: ((String) -> Void)?
    var onCancelled: (() -> Void)?

    private static let frameSize = NSSize(width: 240, height: 240)
    private static let captionHeight: CGFloat = 34

    init() {
        let size = NSSize(width: Self.frameSize.width, height: Self.frameSize.height + Self.captionHeight)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // .screenSaver, not .floating: aiming the lens at a QR embedded in a
        // chat image often means opening that app's own full-size image
        // viewer first, which can itself sit above a merely-floating window
        // — leaving the lens stuck behind it, unusable. This is the highest
        // conventional level, the same one screen savers and "always on
        // top" utilities use to stay above literally everything.
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        super.init(window: panel)
        buildUI(in: panel)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(in panel: NSPanel) {
        guard let content = panel.contentView else { return }

        let frameView = LensFrameView(frame: NSRect(x: 0, y: Self.captionHeight, width: Self.frameSize.width, height: Self.frameSize.height))
        frameView.autoresizingMask = [.width, .height]
        content.addSubview(frameView)
        self.frameView = frameView

        // A solid translucent color rather than NSVisualEffectView: the live
        // blur re-samples the desktop behind the window every frame, which is
        // pure cost for a 34pt caption strip on a window that moves a lot.
        let captionBackground = NSView(frame: NSRect(x: 0, y: 0, width: Self.frameSize.width, height: Self.captionHeight))
        captionBackground.wantsLayer = true
        captionBackground.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        captionBackground.layer?.cornerRadius = 10
        captionBackground.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        content.addSubview(captionBackground)

        let caption = NSTextField(labelWithString: Self.captionText(pinned: false))
        caption.font = .systemFont(ofSize: 11, weight: .medium)
        caption.textColor = .white
        caption.alignment = .center
        caption.frame = NSRect(x: 4, y: 0, width: Self.frameSize.width - 8, height: Self.captionHeight)
        captionBackground.addSubview(caption)
        self.caption = caption
    }

    func show() {
        guard let panel = window else { return }
        reposition(to: NSEvent.mouseLocation)
        panel.orderFrontRegardless()

        // Carbon hotkeys rather than keyDown: the lens is a non-activating
        // panel, so the frontmost app keeps keyboard focus and a plain
        // keyDown for Escape never reaches it.
        escapeHotKey.register(keyCode: UInt32(kVK_Escape), modifiers: 0) { [weak self] in
            DispatchQueue.main.async { self?.cancel() }
        }
        let store = SettingsStore.shared
        pinHotKey.register(keyCode: store.pinKeyCode, modifiers: store.pinKeyModifiers) { [weak self] in
            DispatchQueue.main.async { self?.isPinned.toggle() }
        }

        // Pinning lets the cursor move away (e.g. to open another app's
        // full-size image viewer) without taking the lens with it.
        var lastMouse: NSPoint?
        let follow = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, !self.isPinned else { return }
            let mouse = NSEvent.mouseLocation
            guard mouse != lastMouse else { return }
            lastMouse = mouse
            self.reposition(to: mouse)
        }
        // .common, not the default mode, so tracking doesn't freeze while
        // Oboor's own status menu runs its event-tracking loop.
        RunLoop.main.add(follow, forMode: .common)
        followTimer = follow

        let windowID = CGWindowID(panel.windowNumber)
        var scanInFlight = false
        let scan = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let window = self.window, !scanInFlight else { return }
            // Re-assert front placement on every tick, not just at show():
            // the user often needs to open another app's own full-size
            // image viewer *after* the lens is already up (to see a small
            // embedded QR clearly enough to aim at), which can otherwise
            // raise itself above the lens later rather than before.
            window.orderFrontRegardless()
            scanInFlight = true
            let frame = window.frame
            let scale = window.backingScaleFactor
            let primaryScreenMaxY = NSScreen.screens.first?.frame.maxY ?? 0
            // Detached, not @MainActor: the capture + Vision pass is heavy
            // enough that running it on the main thread stalled the run loop
            // for the ~0.2s tick, which showed up as jitter/ghosting while
            // the lens was moving. Only the tiny bit that touches
            // `self`/the window hops back to the main actor.
            Task.detached(priority: .userInitiated) {
                let payload = await QRDetector.scan(rect: frame, primaryScreenMaxY: primaryScreenMaxY, scale: scale, excludingWindowID: windowID)
                await MainActor.run {
                    scanInFlight = false
                    // The user may have hit Escape while this scan was in
                    // flight — don't resurrect a preview for a lens they
                    // already dismissed.
                    if let payload, !self.isFinished { self.found(payload) }
                }
            }
        }
        RunLoop.main.add(scan, forMode: .common)
        scanTimer = scan
    }

    private static func captionText(pinned: Bool) -> String {
        let store = SettingsStore.shared
        let key = KeyRecorderView.symbolString(keyCode: store.pinKeyCode, modifiers: store.pinKeyModifiers)
        return String(format: L.t(pinned ? .lensCaptionPinned : .lensCaption), key)
    }

    private func reposition(to mouse: NSPoint) {
        guard let panel = window else { return }
        let size = panel.frame.size
        let gap: CGFloat = 6
        // Up-left of the cursor so the arrow sits just past the lens's
        // bottom-right corner instead of covering what's being aimed at;
        // flips side where the screen edge leaves no room.
        var origin = NSPoint(x: mouse.x - size.width - gap, y: mouse.y + gap)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            if origin.x < screen.frame.minX { origin.x = mouse.x + gap }
            if origin.y + size.height > screen.frame.maxY { origin.y = mouse.y - size.height - gap }
            origin.y = max(origin.y, screen.frame.minY)
        }
        panel.setFrameOrigin(origin)
    }

    private func tearDown() {
        escapeHotKey.unregister()
        pinHotKey.unregister()
        followTimer?.invalidate()
        followTimer = nil
        scanTimer?.invalidate()
        scanTimer = nil
        window?.orderOut(nil)
    }

    // Both paths are one-shot: Esc is delivered asynchronously and can land
    // right after a scan already finished (or vice versa).
    private func found(_ payload: String) {
        guard !isFinished else { return }
        isFinished = true
        tearDown()
        onFound?(payload)
    }

    func cancel() {
        guard !isFinished else { return }
        isFinished = true
        tearDown()
        onCancelled?()
    }
}

// MARK: - Contact / Calendar saving

enum ContactSaver {
    static func save(name: String?, phone: String?, email: String?, org: String?, completion: @escaping (Bool) -> Void) {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { DispatchQueue.main.async { completion(false) }; return }
            let contact = CNMutableContact()
            let parts = (name ?? "").split(separator: " ", maxSplits: 1).map(String.init)
            contact.givenName = parts.first ?? ""
            if parts.count > 1 { contact.familyName = parts[1] }
            if let org, !org.isEmpty { contact.organizationName = org }
            if let phone, !phone.isEmpty {
                contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
            }
            if let email, !email.isEmpty {
                contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
            }
            let request = CNSaveRequest()
            request.add(contact, toContainerWithIdentifier: nil)
            do {
                try store.execute(request)
                DispatchQueue.main.async { completion(true) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
}

enum CalendarSaver {
    static func save(title: String?, location: String?, start: Date?, end: Date?, completion: @escaping (Bool) -> Void) {
        let store = EKEventStore()
        // Write-only: Oboor only ever adds an event and never needs to read
        // the user's calendar.
        store.requestWriteOnlyAccessToEvents { granted, _ in
            guard granted else { DispatchQueue.main.async { completion(false) }; return }
            let event = EKEvent(eventStore: store)
            event.title = title ?? L.t(.calendarNoTitle)
            event.location = location
            event.startDate = start ?? Date()
            event.endDate = end ?? (start ?? Date()).addingTimeInterval(3600)
            event.calendar = store.defaultCalendarForNewEvents
            do {
                try store.save(event, span: .thisEvent)
                DispatchQueue.main.async { completion(true) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
}

// MARK: - Shared centering helpers

/// Adds `view` to `stack`, horizontally centered inside a container that
/// spans the stack's usable width (its width minus `edgeInsets`, so the
/// container never fights the stack's own inset constraints). Top/bottom are
/// pinned, since these rows' height already matches their content.
/// The container is appended to `stack` before any constraint is activated:
/// the width constraint references `stack`, and AppKit throws
/// NSGenericException ("no common ancestor") otherwise — which once aborted
/// every preview build right after a code was decoded. Returns nothing, so a
/// caller can't add the container to the stack a second time.
func addCenteredHorizontally(_ view: NSView, to stack: NSStackView) {
    let container = NSView()
    view.translatesAutoresizingMaskIntoConstraints = false
    container.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    stack.addArrangedSubview(container)
    NSLayoutConstraint.activate([
        view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        view.topAnchor.constraint(equalTo: container.topAnchor),
        view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        view.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
        view.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
        container.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -(stack.edgeInsets.left + stack.edgeInsets.right)),
    ])
}

/// Like `addCenteredHorizontally`, for a detail card (a compact stack of
/// label/value rows) that is also centered vertically, inside a container at
/// least `minHeight` tall, instead of sitting in its top-leading corner.
/// Same append-before-activate ordering, for the same reason.
func addCentered(_ view: NSView, to stack: NSStackView, minHeight: CGFloat) {
    let container = NSView()
    view.translatesAutoresizingMaskIntoConstraints = false
    container.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    stack.addArrangedSubview(container)
    NSLayoutConstraint.activate([
        view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        view.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
        view.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
        container.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -(stack.edgeInsets.left + stack.edgeInsets.right)),
        container.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight),
    ])
}

// MARK: - Private browsing

/// Browsers with a command-line flag for a private window. Safari has none
/// (short of UI scripting), so it can't be offered.
enum PrivateBrowser {
    typealias Choice = (bundleID: String, flag: String, app: URL)

    private static let known: [(bundleID: String, flag: String)] = [
        ("com.google.Chrome", "--incognito"), ("com.brave.Browser", "--incognito"),
        ("com.microsoft.edgemac", "--inprivate"), ("com.vivaldi.Vivaldi", "--incognito"),
    ]

    static func installed() -> [Choice] {
        known.compactMap { browser in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID)
                .map { (bundleID: browser.bundleID, flag: browser.flag, app: $0) }
        }
    }

    static func displayName(of app: URL) -> String {
        app.deletingPathExtension().lastPathComponent
    }

    private static func defaultBrowserID() -> String? {
        NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)
            .flatMap { Bundle(url: $0)?.bundleIdentifier }
    }

    /// The default browser when it supports private windows, otherwise the
    /// first installed one that does.
    static func automatic() -> Choice? {
        let available = installed()
        let defaultID = defaultBrowserID()
        return available.first { $0.bundleID == defaultID } ?? available.first
    }

    /// The browser picked in Settings while it's still installed, otherwise automatic.
    static func resolve() -> (choice: Choice, isDefault: Bool)? {
        let picked = SettingsStore.shared.privateBrowserID.flatMap { id in installed().first { $0.bundleID == id } }
        guard let choice = picked ?? automatic() else { return nil }
        return (choice, choice.bundleID == defaultBrowserID())
    }
}

// MARK: - Preview window

final class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PreviewWindowController: NSWindowController, WKNavigationDelegate, NSWindowDelegate {
    private let payload: ParsedPayload
    private var webView: WKWebView?
    private var statusLabel: NSTextField?
    private var iconView: NSImageView?
    private var titleLabel: NSTextField?
    private var subtitleLabel: NSTextField?
    private var wifiPasswordLabel: NSTextField?
    private var wifiPasswordToggleButton: NSButton?
    private var wifiPasswordPlaintext: String?
    private var wifiPasswordRevealed = false
    private var actionsStack: NSStackView?
    private var appStoreBundleID: String?
    private static let bodyMinHeight: CGFloat = 200

    init(payload: ParsedPayload) {
        self.payload = payload
        let panel = PreviewPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 640),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = L.t(.previewTitle)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: panel)
        panel.delegate = self
        buildUI()
        positionNearMouse()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// A closed preview stays alive until the next scan replaces it, and its
    /// WKWebView kept playing a page's audio/video after the window closed.
    func windowWillClose(_ notification: Notification) {
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
    }

    private func positionNearMouse() {
        let mouse = NSEvent.mouseLocation
        // The screen under the cursor, not NSScreen.main (the screen with the
        // key window), which put the preview on the wrong monitor.
        guard let window, let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        var origin = NSPoint(x: mouse.x - window.frame.width / 2, y: mouse.y - window.frame.height / 2)
        origin.x = min(max(origin.x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - window.frame.width - 8)
        origin.y = min(max(origin.y, screen.visibleFrame.minY + 8), screen.visibleFrame.maxY - window.frame.height - 8)
        window.setFrameOrigin(origin)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        // Header
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10

        let icon = NSImageView()
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        icon.image = NSImage(systemSymbolName: symbolName(for: payload.kind), accessibilityDescription: nil)
        icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 36).isActive = true
        iconView = icon

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        let title = NSTextField(labelWithString: titleText(for: payload.kind))
        title.font = .boldSystemFont(ofSize: 15)
        title.lineBreakMode = .byTruncatingTail
        let subtitle = NSTextField(labelWithString: subtitleText(for: payload.kind))
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingMiddle
        titleLabel = title
        subtitleLabel = subtitle
        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(subtitle)

        header.addArrangedSubview(icon)
        header.addArrangedSubview(textStack)

        addCenteredHorizontally(header, to: root)

        root.addArrangedSubview(NSBox.hairline())

        // Body — addBody attaches and sizes whichever view fits the payload
        // (live web preview, scrollable text, or a centered detail card).
        addBody(for: payload.kind, to: root)

        root.addArrangedSubview(NSBox.hairline())

        // Status label (feedback for copy/add actions)
        let status = NSTextField(labelWithString: "")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        statusLabel = status
        root.addArrangedSubview(status)

        // Actions
        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 8
        buildActionButtons(for: payload.kind).forEach { actions.addArrangedSubview($0) }
        actionsStack = actions
        addCenteredHorizontally(actions, to: root)

        if payload.kind.isAppStore {
            fetchAppStoreInfo()
        }
    }

    private func symbolName(for kind: PayloadKind) -> String {
        switch kind {
        case .url: return "link"
        case .appStore: return "app.badge"
        case .social: return "person.crop.circle"
        case .wifi: return "wifi"
        case .contact: return "person.crop.circle.badge.plus"
        case .email: return "envelope"
        case .phone: return "phone"
        case .sms: return "message"
        case .geo: return "mappin.and.ellipse"
        case .calendarEvent: return "calendar.badge.plus"
        case .text: return "text.alignleft"
        }
    }

    private func titleText(for kind: PayloadKind) -> String {
        switch kind {
        case .url(let url): return url.host ?? url.absoluteString
        case .appStore: return L.t(.loadingAppStore)
        case .social(let url, _): return url.host ?? url.absoluteString
        case .wifi(let ssid, _, _): return ssid.isEmpty ? L.t(.wifiCardTitle) : ssid
        case .contact(let name, _, _, _): return name?.isEmpty == false ? name! : L.t(.contactNoName)
        case .email(let address): return address
        case .phone(let number): return number
        case .sms: return L.t(.smsCardTitle)
        case .geo: return L.t(.geoCardTitle)
        case .calendarEvent(let title, _, _, _): return title?.isEmpty == false ? title! : L.t(.calendarNoTitle)
        case .text: return L.t(.textCardTitle)
        }
    }

    private func subtitleText(for kind: PayloadKind) -> String {
        switch kind {
        case .url(let url): return url.absoluteString
        case .appStore(let url): return url.absoluteString
        case .social(let url, _): return url.absoluteString
        case .wifi(_, _, let hidden): return hidden ? L.t(.wifiHiddenBadge) : L.t(.wifiCardTitle)
        case .contact(_, let phone, let email, _): return [phone, email].compactMap { $0 }.joined(separator: " · ")
        case .email: return L.t(.emailCardTitle)
        case .phone: return L.t(.phoneCardTitle)
        case .sms(let number, _): return number
        case .geo(let coords, _): return coords
        case .calendarEvent(_, let location, _, _): return location ?? ""
        case .text(let value): return String(value.prefix(80))
        }
    }

    private func addBody(for kind: PayloadKind, to root: NSStackView) {
        switch kind {
        case .url(let url), .social(let url, _):
            let wv = WKWebView(frame: .zero, configuration: {
                let config = WKWebViewConfiguration()
                config.websiteDataStore = .nonPersistent()
                return config
            }())
            // Defense in depth against the App Store bug below: never let a
            // live preview page redirect straight into a native app on its
            // own — only the explicit "Open in App" button may do that.
            wv.navigationDelegate = self
            wv.load(URLRequest(url: url))
            webView = wv
            addFullWidthBody(wv, to: root)

        case .appStore(let url):
            // Deliberately NOT a WKWebView: loading an apps.apple.com URL
            // triggers macOS's own universal-link handling to silently
            // launch the native App Store app (or the app itself, if
            // already installed) with no click at all — confirmed by the
            // user scanning a code for an app already on their Mac. The
            // icon/name card (populated by fetchAppStoreInfo below) is a
            // static preview; opening only ever happens via the button.
            addCentered(detailStack([(L.t(.fieldLink), url.absoluteString)]), to: root, minHeight: Self.bodyMinHeight)

        case .wifi(let ssid, let password, let hidden):
            var rows: [(String, String)] = [(L.t(.wifiCardTitle), ssid.isEmpty ? "—" : ssid)]
            if hidden { rows.append(("", L.t(.wifiHiddenBadge))) }
            let stack = detailStack(rows)
            if let password {
                wifiPasswordPlaintext = password
                let (row, valueField) = makeRow(label: L.t(.fieldPassword), value: String(repeating: "•", count: password.count))
                wifiPasswordLabel = valueField
                stack.addArrangedSubview(row)
            }
            addCentered(stack, to: root, minHeight: Self.bodyMinHeight)

        case .contact(let name, let phone, let email, let org):
            addCentered(detailStack([
                (L.t(.fieldName), name),
                (L.t(.fieldPhone), phone),
                (L.t(.fieldEmail), email),
                (L.t(.fieldOrg), org),
            ].compactMap { label, value in value.map { (label, $0) } }), to: root, minHeight: Self.bodyMinHeight)

        case .email(let address):
            addCentered(detailStack([(L.t(.fieldEmail), address)]), to: root, minHeight: Self.bodyMinHeight)

        case .phone(let number):
            addCentered(detailStack([(L.t(.fieldPhone), number)]), to: root, minHeight: Self.bodyMinHeight)

        case .sms(let number, let body):
            let rows: [(String, String?)] = [(L.t(.fieldPhone), number), (L.t(.fieldMessage), body)]
            addCentered(detailStack(rows.compactMap { label, value in value.map { (label, $0) } }), to: root, minHeight: Self.bodyMinHeight)

        case .geo(let coords, _):
            addCentered(detailStack([(L.t(.fieldCoordinates), coords)]), to: root, minHeight: Self.bodyMinHeight)

        case .calendarEvent(let title, let location, let start, let end):
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            addCentered(detailStack([
                (L.t(.fieldTitle), title),
                (L.t(.fieldLocation), location),
                (L.t(.fieldStart), start.map(df.string)),
                (L.t(.fieldEnd), end.map(df.string)),
            ].compactMap { label, value in value.map { (label, $0) } }), to: root, minHeight: Self.bodyMinHeight)

        case .text(let value):
            // scrollableTextView wires up the text container to track the
            // scroll view's width, which a bare zero-frame NSTextView doesn't.
            let scroll = NSTextView.scrollableTextView()
            scroll.borderType = .noBorder
            if let textView = scroll.documentView as? NSTextView {
                textView.string = value
                textView.isEditable = false
                textView.font = .systemFont(ofSize: 13)
            }
            addFullWidthBody(scroll, to: root)
        }
    }

    /// Live web preview and plain-text bodies span root's width, with the
    /// same minimum height as the detail cards.
    private func addFullWidthBody(_ view: NSView, to root: NSStackView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(view)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: root.widthAnchor),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.bodyMinHeight),
        ])
    }

    private func makeRow(label: String, value: String) -> (row: NSView, valueField: NSTextField) {
        let row = NSStackView()
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 2
        if !label.isEmpty {
            let l = NSTextField(labelWithString: label)
            l.font = .systemFont(ofSize: 10, weight: .semibold)
            l.textColor = .secondaryLabelColor
            row.addArrangedSubview(l)
        }
        let v = NSTextField(labelWithString: value)
        v.font = .systemFont(ofSize: 13)
        v.lineBreakMode = .byWordWrapping
        v.maximumNumberOfLines = 3
        row.addArrangedSubview(v)
        return (row, v)
    }

    private func detailStack(_ rows: [(String, String)]) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        for (label, value) in rows {
            stack.addArrangedSubview(makeRow(label: label, value: value).row)
        }
        return stack
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }

    private func buildActionButtons(for kind: PayloadKind) -> [NSButton] {
        switch kind {
        case .url, .social:
            var buttons = [button(L.t(.openInBrowser), action: #selector(openInBrowser))]
            if let browser = PrivateBrowser.resolve() {
                let title = browser.isDefault
                    ? L.t(.openPrivately)
                    : String(format: L.t(.openPrivatelyIn), PrivateBrowser.displayName(of: browser.choice.app))
                buttons.append(button(title, action: #selector(openPrivately)))
            }
            buttons.append(button(L.t(.copyLink), action: #selector(copyLink)))
            if case .social(_, let scheme) = kind, let scheme, NSWorkspace.shared.urlForApplication(toOpen: scheme) != nil {
                buttons.append(button(L.t(.openInApp), action: #selector(openInApp)))
            }
            return buttons

        case .appStore:
            return [button(L.t(.openInAppStore), action: #selector(openInBrowser)), button(L.t(.copyLink), action: #selector(copyLink))]

        case .wifi:
            var buttons = [button(L.t(.wifiOpenSettings), action: #selector(openWiFiSettings))]
            if case .wifi(_, let password, _) = kind, password != nil {
                buttons.append(button(L.t(.wifiCopyPassword), action: #selector(copyWiFiPassword)))
                let toggle = button(L.t(.wifiShowPassword), action: #selector(toggleWiFiPasswordVisibility))
                wifiPasswordToggleButton = toggle
                buttons.append(toggle)
            }
            return buttons

        case .contact:
            return [button(L.t(.contactAdd), action: #selector(addContact))]

        case .calendarEvent:
            return [button(L.t(.calendarAdd), action: #selector(addCalendarEvent))]

        case .email:
            return [button(L.t(.emailOpen), action: #selector(openInBrowser))]

        case .phone:
            return [button(L.t(.phoneCall), action: #selector(openInBrowser)), button(L.t(.phoneCopy), action: #selector(copyPhone))]

        case .sms:
            return [button(L.t(.smsOpen), action: #selector(openInBrowser))]

        case .geo:
            return [button(L.t(.geoOpen), action: #selector(openInBrowser))]

        case .text:
            return [button(L.t(.copyText), action: #selector(copyText))]
        }
    }

    private func showStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    @objc private func openInBrowser() {
        // open() returns false when nothing handles the scheme (e.g. tel:
        // with no calling app) — that used to fail silently and still log a visit.
        guard let url = destinationURL(), NSWorkspace.shared.open(url) else { showStatus(L.t(.genericOpenFailed)); return }
        recordVisit(url: url)
    }

    @objc private func openPrivately() {
        guard let url = destinationURL(), let browser = PrivateBrowser.resolve()?.choice else {
            showStatus(L.t(.genericOpenFailed)); return
        }
        // OpenConfiguration.arguments only reach a browser that isn't running
        // yet, so with the browser already open the link landed in a normal
        // window. `open -na … --args` hands the flag to the running instance.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", browser.app.path, "--args", browser.flag, url.absoluteString]
        do {
            try process.run()
            recordVisit(url: url)
        } catch {
            showStatus(L.t(.genericOpenFailed))
        }
    }

    /// History only ever tracks actual link visits (url/appStore/social),
    /// not every action that calls this — email/phone/sms/geo results also
    /// route their button through openInBrowser() but aren't "links."
    private func recordVisit(url: URL) {
        switch payload.kind {
        case .url, .appStore, .social:
            // An App Store title still reads "Loading…" if the lookup hasn't returned.
            let title = titleLabel?.stringValue ?? ""
            let usable = !title.isEmpty && title != L.t(.loadingAppStore)
            HistoryStore.shared.record(url: url.absoluteString, title: usable ? title : (url.host ?? url.absoluteString))
        default:
            break
        }
    }

    @objc private func copyLink() {
        guard let url = destinationURL() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.absoluteString, forType: .string)
        showStatus(L.t(.copied))
    }

    @objc private func openInApp() {
        switch payload.kind {
        case .social(_, let scheme):
            if let scheme {
                NSWorkspace.shared.open(scheme)
                if let url = destinationURL() { recordVisit(url: url) }
            }
        case .appStore:
            if let bundleID = appStoreBundleID, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.open(appURL)
                if let url = destinationURL() { recordVisit(url: url) }
            }
        default:
            break
        }
    }

    @objc private func openWiFiSettings() {
        ScreenCapturePermission.openSystemSettingsWiFi()
    }

    @objc private func copyWiFiPassword() {
        if case .wifi(_, let password, _) = payload.kind, let password {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(password, forType: .string)
            showStatus(L.t(.copied))
        }
    }

    @objc private func toggleWiFiPasswordVisibility() {
        guard let label = wifiPasswordLabel, let password = wifiPasswordPlaintext else { return }
        wifiPasswordRevealed.toggle()
        label.stringValue = wifiPasswordRevealed ? password : String(repeating: "•", count: password.count)
        wifiPasswordToggleButton?.title = wifiPasswordRevealed ? L.t(.wifiHidePassword) : L.t(.wifiShowPassword)
    }

    @objc private func addContact() {
        guard case .contact(let name, let phone, let email, let org) = payload.kind else { return }
        ContactSaver.save(name: name, phone: phone, email: email, org: org) { [weak self] ok in
            self?.showStatus(ok ? L.t(.contactAdded) : L.t(.contactAddFailed))
        }
    }

    @objc private func addCalendarEvent() {
        guard case .calendarEvent(let title, let location, let start, let end) = payload.kind else { return }
        CalendarSaver.save(title: title, location: location, start: start, end: end) { [weak self] ok in
            self?.showStatus(ok ? L.t(.calendarAdded) : L.t(.calendarAddFailed))
        }
    }

    @objc private func copyPhone() {
        if case .phone(let number) = payload.kind {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(number, forType: .string)
            showStatus(L.t(.copied))
        }
    }

    @objc private func copyText() {
        if case .text(let value) = payload.kind {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(value, forType: .string)
            showStatus(L.t(.copied))
        }
    }

    private func destinationURL() -> URL? {
        switch payload.kind {
        case .url(let url), .appStore(let url), .social(let url, _): return url
        case .email(let address): return URL(string: "mailto:\(address)")
        case .phone(let number): return URL(string: "tel:\(number.filter { !$0.isWhitespace })")
        case .sms(let number, _): return URL(string: "sms:\(number.filter { !$0.isWhitespace })")
        case .geo(_, let mapsURL): return mapsURL
        default: return nil
        }
    }

    /// Scheme allowlist for the live preview: only ever renders http/https
    /// content, and cancels anything else outright rather than letting
    /// WebKit decide — a page redirecting itself to a custom URL scheme
    /// (a common "open in app" trick some sites embed) must not be able to
    /// launch a native app on its own.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let scheme = navigationAction.request.url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    private func fetchAppStoreInfo() {
        guard case .appStore(let url) = payload.kind else { return }
        // Any failure below falls back to the host, instead of leaving the
        // title stuck on "Loading…" forever.
        let giveUp = { [weak self] in
            DispatchQueue.main.async { self?.titleLabel?.stringValue = url.host ?? url.absoluteString }
        }
        guard let idRange = url.path.range(of: "/id[0-9]+", options: .regularExpression) else { giveUp(); return }
        let id = String(url.path[idRange].dropFirst(3))
        // Without a country the lookup only searches the US store, so apps
        // missing there (common for Saudi-only apps) never resolved.
        let pathCountry = url.path.split(separator: "/").first.map(String.init).flatMap { $0.count == 2 && $0.allSatisfy(\.isLetter) ? $0 : nil }
        let country = (pathCountry ?? Locale.current.region?.identifier ?? "us").lowercased()
        guard let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(id)&country=\(country)") else { giveUp(); return }
        URLSession.shared.dataTask(with: lookupURL) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first else { giveUp(); return }
            let name = first["trackName"] as? String
            let seller = first["sellerName"] as? String
            let artwork = (first["artworkUrl512"] as? String) ?? (first["artworkUrl100"] as? String)
            let bundleID = first["bundleId"] as? String
            DispatchQueue.main.async {
                guard let self else { return }
                if let name { self.titleLabel?.stringValue = name }
                if let seller { self.subtitleLabel?.stringValue = seller }
                if let artwork, let artworkURL = URL(string: artwork) {
                    URLSession.shared.dataTask(with: artworkURL) { imgData, _, _ in
                        guard let imgData, let image = NSImage(data: imgData) else { return }
                        DispatchQueue.main.async { self.iconView?.image = image }
                    }.resume()
                }
                // Only revealed once we actually know the app is already
                // installed — the lookup itself finishing tells us nothing
                // about that, and the button must never appear (let alone
                // do anything) for an app the user doesn't already have.
                if let bundleID, NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
                    self.appStoreBundleID = bundleID
                    self.actionsStack?.addArrangedSubview(self.button(L.t(.openInApp), action: #selector(self.openInApp)))
                }
            }
        }.resume()
    }
}

extension PayloadKind {
    var isAppStore: Bool { if case .appStore = self { return true }; return false }
}

extension NSBox {
    static func hairline() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

extension ScreenCapturePermission {
    static func openSystemSettingsWiFi() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.wifi-settings") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - History window

final class HistoryWindowController: NSWindowController {
    private var stack: NSStackView?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = L.t(.historyWindowTitle)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .oboorHistoryChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .oboorSettingsChanged, object: nil)
    }

    /// The window is cached for the app's lifetime, so without this it kept
    /// the language it was first opened in.
    @objc private func settingsChanged() {
        window?.title = L.t(.historyWindowTitle)
        reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
        ])
        stack = root
        reload()
    }

    @objc private func reload() {
        guard let stack else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let entries = HistoryStore.shared.entries
        guard !entries.isEmpty else {
            let label = NSTextField(labelWithString: L.t(.historyEmpty))
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
            return
        }

        for entry in entries {
            let row = NSStackView()
            row.orientation = .vertical
            row.alignment = .centerX
            row.spacing = 2

            let title = NSButton(title: entry.title, target: self, action: #selector(openEntry(_:)))
            title.bezelStyle = .inline
            title.isBordered = false
            title.contentTintColor = .linkColor
            title.identifier = NSUserInterfaceItemIdentifier(entry.url)
            title.lineBreakMode = .byTruncatingTail

            let sub = NSTextField(labelWithString: entry.url)
            sub.font = .systemFont(ofSize: 10)
            sub.textColor = .secondaryLabelColor
            sub.lineBreakMode = .byTruncatingMiddle

            row.addArrangedSubview(title)
            row.addArrangedSubview(sub)

            addCenteredHorizontally(row, to: stack)
        }

        let clear = NSButton(title: L.t(.historyClear), target: self, action: #selector(clearHistory))
        clear.bezelStyle = .rounded
        stack.addArrangedSubview(clear)
    }

    @objc private func openEntry(_ sender: NSButton) {
        guard let urlString = sender.identifier?.rawValue, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func clearHistory() {
        HistoryStore.shared.clear()
    }
}

// MARK: - Settings window

final class SettingsWindowController: NSWindowController {
    /// Lets the app delegate own the single shared HistoryWindowController
    /// instance — Settings just asks for it, the same pattern
    /// applicationDidFinishLaunching already uses for the menu item.
    var onShowHistory: (() -> Void)?
    private var builtLanguage = SettingsStore.shared.language

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = L.t(.settingsWindowTitle)
        window.isReleasedWhenClosed = false
        // Without this it opens at the literal (0, 0) origin passed above,
        // i.e. the screen's bottom-left corner, instead of anywhere near
        // the middle of the display.
        window.center()
        super.init(window: window)
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .oboorSettingsChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The window is cached for the app's lifetime, so switching language
    /// left this very window in the old language until relaunch.
    @objc private func settingsChanged() {
        let language = SettingsStore.shared.language
        guard language != builtLanguage else { return }
        builtLanguage = language
        // Deferred: this fires from inside the language popup's own action,
        // and rebuilding removes that popup.
        DispatchQueue.main.async { [weak self] in
            guard let self, let content = self.window?.contentView else { return }
            content.subviews.forEach { $0.removeFromSuperview() }
            self.window?.title = L.t(.settingsWindowTitle)
            self.buildUI()
        }
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let store = SettingsStore.shared

        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 16
        grid.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            grid.topAnchor.constraint(equalTo: content.topAnchor),
        ])

        // Hotkey row
        let hotkeyRow = NSStackView()
        hotkeyRow.orientation = .horizontal
        hotkeyRow.spacing = 8
        let hotkeyLabel = NSTextField(labelWithString: L.t(.hotkeyRow))
        let recorder = KeyRecorderView(keyCode: store.hotKeyCode, modifiers: store.hotKeyModifiers)
        // The two shortcuts can't share a combo: Carbon refuses a duplicate
        // registration, leaving one of them silently dead.
        recorder.onChange = { code, mods in
            guard code != store.pinKeyCode || mods != store.pinKeyModifiers else { return false }
            store.setHotKey(code: code, modifiers: mods)
            return true
        }
        hotkeyRow.addArrangedSubview(hotkeyLabel)
        hotkeyRow.addArrangedSubview(recorder)
        grid.addArrangedSubview(hotkeyRow)

        // Pin key row — a bare key is allowed, since it's only claimed while
        // the lens is up.
        let pinRow = NSStackView()
        pinRow.orientation = .horizontal
        pinRow.spacing = 8
        let pinLabel = NSTextField(labelWithString: L.t(.pinKeyRow))
        let pinRecorder = KeyRecorderView(keyCode: store.pinKeyCode, modifiers: store.pinKeyModifiers, requiresModifier: false)
        pinRecorder.onChange = { code, mods in
            guard code != store.hotKeyCode || mods != store.hotKeyModifiers else { return false }
            store.setPinKey(code: code, modifiers: mods)
            return true
        }
        pinRow.addArrangedSubview(pinLabel)
        pinRow.addArrangedSubview(pinRecorder)
        grid.addArrangedSubview(pinRow)

        // Language row
        let langRow = NSStackView()
        langRow.orientation = .horizontal
        langRow.spacing = 8
        let langLabel = NSTextField(labelWithString: L.t(.languageRow))
        let langPopup = NSPopUpButton()
        AppLanguage.allCases.forEach { langPopup.addItem(withTitle: $0.displayName) }
        langPopup.selectItem(at: AppLanguage.allCases.firstIndex(of: store.language) ?? 0)
        langPopup.target = self
        langPopup.action = #selector(languageChanged(_:))
        langRow.addArrangedSubview(langLabel)
        langRow.addArrangedSubview(langPopup)
        grid.addArrangedSubview(langRow)

        // Private-browser row — only when there's something to choose from.
        let browsers = PrivateBrowser.installed()
        if !browsers.isEmpty {
            let browserRow = NSStackView()
            browserRow.orientation = .horizontal
            browserRow.spacing = 8
            let browserLabel = NSTextField(labelWithString: L.t(.privateBrowserRow))
            let browserPopup = NSPopUpButton()
            let automaticTitle = PrivateBrowser.automatic()
                .map { "\(L.t(.privateBrowserAutomatic)) (\(PrivateBrowser.displayName(of: $0.app)))" }
                ?? L.t(.privateBrowserAutomatic)
            browserPopup.addItem(withTitle: automaticTitle)
            browsers.forEach { browserPopup.addItem(withTitle: PrivateBrowser.displayName(of: $0.app)) }
            let pickedIndex = store.privateBrowserID.flatMap { id in browsers.firstIndex { $0.bundleID == id } }
            browserPopup.selectItem(at: pickedIndex.map { $0 + 1 } ?? 0)
            browserPopup.target = self
            browserPopup.action = #selector(privateBrowserChanged(_:))
            browserRow.addArrangedSubview(browserLabel)
            browserRow.addArrangedSubview(browserPopup)
            grid.addArrangedSubview(browserRow)
        }

        // Launch at login
        let loginCheckbox = NSButton(checkboxWithTitle: L.t(.launchAtLoginCheckbox), target: self, action: #selector(loginToggled(_:)))
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
        grid.addArrangedSubview(loginCheckbox)

        // Reaching History from here (not just the menu bar dropdown)
        // matters because opening Oboor.app itself — a double-click on
        // Desktop — lands here via applicationShouldHandleReopen, and that
        // was the only door into the app the user had in mind.
        let historyButton = NSButton(title: L.t(.historyMenuItem), target: self, action: #selector(openHistory))
        historyButton.bezelStyle = .rounded
        grid.addArrangedSubview(historyButton)
    }

    @objc private func privateBrowserChanged(_ sender: NSPopUpButton) {
        let browsers = PrivateBrowser.installed()
        let index = sender.indexOfSelectedItem - 1
        SettingsStore.shared.privateBrowserID = browsers.indices.contains(index) ? browsers[index].bundleID : nil
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        SettingsStore.shared.language = AppLanguage.allCases[sender.indexOfSelectedItem]
    }

    @objc private func loginToggled(_ sender: NSButton) {
        LoginItem.setEnabled(sender.state == .on)
    }

    @objc private func openHistory() {
        onShowHistory?()
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKey = GlobalHotKey(.scan)
    private var lens: LensWindowController?
    private var preview: PreviewWindowController?
    private var settings: SettingsWindowController?
    private var history: HistoryWindowController?
    private var registeredHotKey: (code: UInt32, modifiers: UInt32)?
    private var settingsMenuItem: NSMenuItem!
    private var scanMenuItem: NSMenuItem!
    private var historyMenuItem: NSMenuItem!
    private var quitMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        SettingsStore.shared.enableLoginItemOnFirstRun()
        registerHotKey()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: L.t(.statusItemAccessibility))

        scanMenuItem = NSMenuItem(title: L.t(.scanNowMenuItem), action: #selector(startScan), keyEquivalent: "")
        historyMenuItem = NSMenuItem(title: L.t(.historyMenuItem), action: #selector(showHistory), keyEquivalent: "")
        settingsMenuItem = NSMenuItem(title: L.t(.settingsMenuItem), action: #selector(showSettings), keyEquivalent: "")
        quitMenuItem = NSMenuItem(title: L.t(.quitMenuItem), action: #selector(quit), keyEquivalent: "")
        let menu = NSMenu()
        menu.addItem(scanMenuItem)
        menu.addItem(historyMenuItem)
        menu.addItem(.separator())
        menu.addItem(settingsMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .oboorSettingsChanged, object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return true
    }

    @objc private func settingsChanged() {
        registerHotKey()
        scanMenuItem.title = L.t(.scanNowMenuItem)
        historyMenuItem.title = L.t(.historyMenuItem)
        settingsMenuItem.title = L.t(.settingsMenuItem)
        quitMenuItem.title = L.t(.quitMenuItem)
        statusItem.button?.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: L.t(.statusItemAccessibility))
    }

    private func registerHotKey() {
        let store = SettingsStore.shared
        let wanted = (code: store.hotKeyCode, modifiers: store.hotKeyModifiers)
        guard registeredHotKey == nil || registeredHotKey! != wanted else { return }
        registeredHotKey = wanted
        hotKey.register(keyCode: wanted.code, modifiers: wanted.modifiers) { [weak self] in
            DispatchQueue.main.async { self?.toggleScan() }
        }
    }

    private func toggleScan() {
        if let lens {
            lens.cancel()
            self.lens = nil
            return
        }
        startScan()
    }

    @objc private func startScan() {
        // "Scan a Code Now" from the menu while a lens is already up used to
        // orphan the first one — still on screen, timers still running.
        guard lens == nil else { return }
        guard ScreenCapturePermission.isGranted else {
            requestScreenRecordingPermission()
            return
        }
        let controller = LensWindowController()
        controller.onFound = { [weak self] payload in
            self?.lens = nil
            self?.showPreview(for: payload)
        }
        controller.onCancelled = { [weak self] in
            self?.lens = nil
        }
        lens = controller
        controller.show()
    }

    private func requestScreenRecordingPermission() {
        ScreenCapturePermission.request()
        let alert = NSAlert()
        alert.messageText = L.t(.screenRecordingAlertTitle)
        alert.informativeText = L.t(.screenRecordingAlertBody)
        alert.addButton(withTitle: L.t(.screenRecordingAlertOpenSettings))
        alert.addButton(withTitle: L.t(.screenRecordingAlertCancel))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            ScreenCapturePermission.openSystemSettings()
        }
    }

    private func showPreview(for raw: String) {
        let parsed = PayloadClassifier.classify(raw)
        // Close the previous preview first: replacing the controller while its
        // window stayed open left buttons targeting a deallocated controller.
        preview?.close()
        let controller = PreviewWindowController(payload: parsed)
        preview = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showSettings() {
        if settings == nil {
            settings = SettingsWindowController()
            settings?.onShowHistory = { [weak self] in self?.showHistory() }
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.showWindow(nil)
        settings?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showHistory() {
        if history == nil { history = HistoryWindowController() }
        NSApp.activate(ignoringOtherApps: true)
        history?.showWindow(nil)
        history?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

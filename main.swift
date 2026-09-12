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
    }

    private init() {
        d.register(defaults: [
            Key.hotKeyCode: Int(kVK_ANSI_O),
            Key.hotKeyModifiers: Int(cmdKey | shiftKey),
        ])
    }

    private func changed() {
        NotificationCenter.default.post(name: .oboorSettingsChanged, object: nil)
    }

    var hotKeyCode: UInt32 {
        get { UInt32(d.integer(forKey: Key.hotKeyCode)) }
        set { d.set(Int(newValue), forKey: Key.hotKeyCode); changed() }
    }

    var hotKeyModifiers: UInt32 {
        get { UInt32(d.integer(forKey: Key.hotKeyModifiers)) }
        set { d.set(Int(newValue), forKey: Key.hotKeyModifiers); changed() }
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
             settingsWindowTitle, hotkeyRow, languageRow, launchAtLoginCheckbox, pressCombo,
             lensCaption, screenRecordingAlertTitle, screenRecordingAlertBody,
             screenRecordingAlertOpenSettings, screenRecordingAlertCancel,
             previewTitle, openInBrowser, openPrivately, copyLink, copied,
             openInApp, openInAppStore, loadingAppStore,
             wifiCardTitle, wifiJoin, wifiCopyPassword, wifiOpenSettings, wifiHiddenBadge,
             contactCardTitle, contactAdd, contactAdded, contactAddFailed, contactNoName,
             calendarCardTitle, calendarAdd, calendarAdded, calendarAddFailed, calendarNoTitle,
             emailCardTitle, emailOpen, phoneCardTitle, phoneCall, phoneCopy,
             smsCardTitle, smsOpen, geoCardTitle, geoOpen, textCardTitle, copyText,
             genericOpenFailed, close
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
        .lensCaption: ("وجّه الإطار على رمز QR — Esc للإلغاء", "Aim the frame at a QR code — Esc to cancel"),
        .screenRecordingAlertTitle: ("عُبور يحتاج صلاحية تسجيل الشاشة", "Oboor needs Screen Recording access"),
        .screenRecordingAlertBody: ("عشان يقرأ رمز QR من شاشتك، فعّل الصلاحية من إعدادات النظام ثم أعد فتح عُبور.", "To read a QR code from your screen, grant the permission in System Settings, then relaunch Oboor."),
        .screenRecordingAlertOpenSettings: ("فتح الإعدادات", "Open Settings"),
        .screenRecordingAlertCancel: ("إلغاء", "Cancel"),
        .previewTitle: ("معاينة — عُبور", "Preview — Oboor"),
        .openInBrowser: ("فتح في المتصفح", "Open in Browser"),
        .openPrivately: ("فتح خفي", "Open Privately"),
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

// MARK: - Global hotkey (Carbon)

private var hotKeyToggleHandler: (() -> Void)?

private func hotKeyEventHandler(_ nextHandler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    hotKeyToggleHandler?()
    return noErr
}

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    func register(keyCode: UInt32, modifiers: UInt32, toggle: @escaping () -> Void) {
        hotKeyToggleHandler = toggle
        if !handlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &eventType, nil, nil)
            handlerInstalled = true
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F42524B), id: 1) // 'OBRK'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

/// A click-to-record shortcut field, same interaction as System Settings'
/// own shortcut recorders — lifted from Naqla's KeyRecorderView.
final class KeyRecorderView: NSView {
    var onChange: ((UInt32, UInt32) -> Void)?

    private var keyCode: UInt32
    private var modifiers: UInt32
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

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
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
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty else { NSSound.beep(); return }
        keyCode = UInt32(event.keyCode)
        modifiers = Self.carbonModifiers(from: mods)
        isRecording = false
        onChange?(keyCode, modifiers)
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

    private static func symbolString(keyCode: UInt32, modifiers: UInt32) -> String {
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
    case sms(URL)
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
            if let url = URL(string: trimmed) { return ParsedPayload(raw: raw, kind: .sms(url)) }
        }
        if upper.hasPrefix("GEO:") {
            let coords = String(trimmed.dropFirst(4))
            if let mapsURL = URL(string: "http://maps.apple.com/?ll=\(coords)") {
                return ParsedPayload(raw: raw, kind: .geo(coordinates: coords, mapsURL: mapsURL))
            }
        }
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme.hasPrefix("http"), let host = url.host?.lowercased() {
            if host.contains("apps.apple.com") || host.contains("itunes.apple.com") {
                return ParsedPayload(raw: raw, kind: .appStore(url))
            }
            let socialHosts = ["instagram.com", "twitter.com", "x.com", "tiktok.com", "facebook.com",
                                "linkedin.com", "snapchat.com", "threads.net", "youtube.com", "wa.me", "t.me"]
            if socialHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                return ParsedPayload(raw: raw, kind: .social(url, appScheme: socialAppScheme(for: url, host: host)))
            }
            return ParsedPayload(raw: raw, kind: .url(url))
        }
        return ParsedPayload(raw: raw, kind: .text(trimmed))
    }

    private static func classifyWiFi(_ raw: String) -> PayloadKind {
        let content = raw.dropFirst("WIFI:".count)
        var ssid = ""
        var password: String?
        var hidden = false
        for field in content.split(separator: ";") {
            let parts = field.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0].uppercased() {
            case "S": ssid = parts[1]
            case "P": password = parts[1].isEmpty ? nil : parts[1]
            case "H": hidden = parts[1].lowercased() == "true"
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
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("FN") { name = value }
            else if key.hasPrefix("TEL"), phone == nil { phone = value }
            else if key.hasPrefix("EMAIL"), email == nil { email = value }
            else if key.hasPrefix("ORG") { org = value }
        }
        return .contact(name: name, phone: phone, email: email, org: org)
    }

    private static func classifyMeCard(_ raw: String) -> PayloadKind {
        let content = raw.dropFirst("MECARD:".count)
        var name: String?, phone: String?, email: String?, org: String?
        for field in content.split(separator: ";") {
            let parts = field.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0].uppercased() {
            case "N": name = parts[1].replacingOccurrences(of: ",", with: " ")
            case "TEL": phone = parts[1]
            case "EMAIL": email = parts[1]
            case "ORG": org = parts[1]
            default: break
            }
        }
        return .contact(name: name, phone: phone, email: email, org: org)
    }

    private static func classifyVEvent(_ raw: String) -> PayloadKind {
        var title: String?, location: String?, start: Date?, end: Date?
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        for line in raw.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].uppercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "Z", with: "")
            if key.hasPrefix("SUMMARY") { title = parts[1].trimmingCharacters(in: .whitespaces) }
            else if key.hasPrefix("LOCATION") { location = parts[1].trimmingCharacters(in: .whitespaces) }
            else if key.hasPrefix("DTSTART") { start = formatter.date(from: value) }
            else if key.hasPrefix("DTEND") { end = formatter.date(from: value) }
        }
        return .calendarEvent(title: title, location: location, start: start, end: end)
    }

    private static func socialAppScheme(for url: URL, host: String) -> URL? {
        let username = url.path.split(separator: "/").first.map(String.init)
        if host.contains("instagram.com"), let u = username {
            return URL(string: "instagram://user?username=\(u)")
        }
        if host == "twitter.com" || host == "x.com", let u = username {
            return URL(string: "twitter://user?screen_name=\(u)")
        }
        if host.contains("wa.me") {
            let number = url.path.replacingOccurrences(of: "/", with: "")
            return URL(string: "whatsapp://send?phone=\(number)")
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
    static func scan(rect: NSRect, excludingWindowID windowID: CGWindowID) async -> String? {
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let maxY = mainScreen.frame.maxY
        let cgRect = CGRect(x: rect.origin.x, y: maxY - rect.origin.y - rect.height, width: rect.width, height: rect.height)

        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else { return nil }
        guard let display = content.displays.first(where: { CGRect(x: 0, y: 0, width: $0.width, height: $0.height).intersects(cgRect) }) ?? content.displays.first else {
            return nil
        }
        let excludedWindows = content.windows.filter { $0.windowID == windowID }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let config = SCStreamConfiguration()
        config.width = max(1, Int(cgRect.width))
        config.height = max(1, Int(cgRect.height))
        config.sourceRect = cgRect
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

final class LensPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Draws the magnifier-style scan frame: four corner brackets over an
/// otherwise fully transparent view, so the capture underneath is never
/// obscured by the frame's own chrome.
final class LensFrameView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()

        let accent = NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.72, alpha: 1.0)
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
    private var dragOffset: NSPoint = .zero
    private var dragCatcher: DraggableBackgroundView!
    private var isDragging = false
    private var isCancelled = false
    var onFound: ((String) -> Void)?
    var onCancelled: (() -> Void)?

    private static let frameSize = NSSize(width: 240, height: 240)
    private static let captionHeight: CGFloat = 34

    init() {
        let size = NSSize(width: Self.frameSize.width, height: Self.frameSize.height + Self.captionHeight)
        let panel = LensPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        super.init(window: panel)
        buildUI(in: panel)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(in panel: NSPanel) {
        guard let content = panel.contentView else { return }

        let frameView = LensFrameView(frame: NSRect(x: 0, y: Self.captionHeight, width: Self.frameSize.width, height: Self.frameSize.height))
        frameView.autoresizingMask = [.width, .height]
        content.addSubview(frameView)

        // A solid translucent color rather than NSVisualEffectView: the live
        // blur re-samples the desktop behind the window every frame, which is
        // pure cost for a 34pt caption strip on a window that moves a lot.
        let captionBackground = NSView(frame: NSRect(x: 0, y: 0, width: Self.frameSize.width, height: Self.captionHeight))
        captionBackground.wantsLayer = true
        captionBackground.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        captionBackground.layer?.cornerRadius = 10
        captionBackground.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        content.addSubview(captionBackground)

        let caption = NSTextField(labelWithString: L.t(.lensCaption))
        caption.font = .systemFont(ofSize: 11, weight: .medium)
        caption.textColor = .white
        caption.alignment = .center
        caption.frame = NSRect(x: 4, y: 0, width: Self.frameSize.width - 8, height: Self.captionHeight)
        captionBackground.addSubview(caption)

        let dragCatcher = DraggableBackgroundView(frame: content.bounds)
        dragCatcher.autoresizingMask = [.width, .height]
        dragCatcher.onDrag = { [weak self] delta in
            guard let self, let window = self.window else { return }
            var origin = window.frame.origin
            origin.x += delta.x
            origin.y += delta.y
            window.setFrameOrigin(origin)
        }
        dragCatcher.onDragStart = { [weak self] in self?.isDragging = true }
        dragCatcher.onDragEnd = { [weak self] in self?.isDragging = false }
        dragCatcher.onEscape = { [weak self] in self?.cancel() }
        // Safety net for onDragEnd: if focus gets stolen mid-drag (Mission
        // Control, Cmd+Tab, a notification banner) the panel never gets a
        // mouseUp, so isDragging could otherwise stay stuck true forever and
        // permanently pause scanning.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            self?.isDragging = false
        }
        // Placed ON TOP (not behind): frameView/captionBackground are plain
        // NSViews, and AppKit's default hit-testing picks the frontmost view
        // whose *frame* contains the click regardless of what it actually
        // draws — putting this transparent catcher behind them meant every
        // click on the visible frame or caption was swallowed before ever
        // reaching it, so the lens couldn't be dragged at all.
        content.addSubview(dragCatcher)
        self.dragCatcher = dragCatcher
    }

    func show() {
        guard let panel = window else { return }
        let mouse = NSEvent.mouseLocation
        let origin = NSPoint(x: mouse.x - panel.frame.width / 2, y: mouse.y - panel.frame.height / 2)
        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(dragCatcher)

        let windowID = CGWindowID(panel.windowNumber)
        var scanInFlight = false
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let window = self.window, !scanInFlight, !self.isDragging else { return }
            scanInFlight = true
            let frame = window.frame
            // Detached, not @MainActor: the capture + Vision pass is heavy
            // enough that running it on the main thread stalled the run loop
            // for the ~0.2s tick, which showed up as jitter/ghosting while
            // the user was actively dragging the lens. Only the tiny bit that
            // touches `self`/the window hops back to the main actor.
            Task.detached(priority: .userInitiated) {
                let payload = await QRDetector.scan(rect: frame, excludingWindowID: windowID)
                await MainActor.run {
                    scanInFlight = false
                    // The user may have hit Escape while this scan was in
                    // flight — don't resurrect a preview for a lens they
                    // already dismissed.
                    if let payload, !self.isCancelled { self.found(payload) }
                }
            }
        }
    }

    private func found(_ payload: String) {
        scanTimer?.invalidate()
        scanTimer = nil
        window?.orderOut(nil)
        onFound?(payload)
    }

    func cancel() {
        isCancelled = true
        scanTimer?.invalidate()
        scanTimer = nil
        window?.orderOut(nil)
        onCancelled?()
    }
}

/// A transparent view that turns click-drag into a delta callback and Escape
/// into a callback — lets the borderless lens panel be repositioned and
/// dismissed without any title bar.
final class DraggableBackgroundView: NSView {
    var onDrag: ((NSPoint) -> Void)?
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onEscape: (() -> Void)?
    private var lastDragLocation: NSPoint?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        lastDragLocation = NSEvent.mouseLocation
        onDragStart?()
    }

    // Screen coordinates, never `event.locationInWindow`: the window moves
    // as a result of this very drag, so a window-relative origin shifts out
    // from under the next event. Each move cancelled the previous one on the
    // following event, which read as the lens vibrating and double-imaging.
    override func mouseDragged(with event: NSEvent) {
        guard let last = lastDragLocation else { return }
        let current = NSEvent.mouseLocation
        onDrag?(NSPoint(x: current.x - last.x, y: current.y - last.y))
        lastDragLocation = current
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocation = nil
        onDragEnd?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
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
        store.requestFullAccessToEvents { granted, _ in
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

// MARK: - Preview window

final class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PreviewWindowController: NSWindowController {
    private let payload: ParsedPayload
    private var webView: WKWebView?
    private var statusLabel: NSTextField?
    private var iconView: NSImageView?
    private var titleLabel: NSTextField?
    private var subtitleLabel: NSTextField?

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
        buildUI()
        positionNearMouse()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func positionNearMouse() {
        guard let window, let screen = NSScreen.main else { return }
        let mouse = NSEvent.mouseLocation
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
        header.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        root.addArrangedSubview(NSBox.hairline())

        // Body
        let body = buildBody(for: payload.kind)
        body.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(body)
        body.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        body.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

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
        actions.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(actions)
        actions.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

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
        case .sms(let url): return url.absoluteString
        case .geo(let coords, _): return coords
        case .calendarEvent(_, let location, _, _): return location ?? ""
        case .text(let value): return String(value.prefix(80))
        }
    }

    private func buildBody(for kind: PayloadKind) -> NSView {
        switch kind {
        case .url(let url), .appStore(let url), .social(let url, _):
            let wv = WKWebView(frame: .zero, configuration: {
                let config = WKWebViewConfiguration()
                config.websiteDataStore = .nonPersistent()
                return config
            }())
            wv.load(URLRequest(url: url))
            webView = wv
            return wv

        case .wifi(let ssid, let password, let hidden):
            var rows: [(String, String)] = [(L.t(.wifiCardTitle), ssid.isEmpty ? "—" : ssid)]
            if hidden { rows.append(("", L.t(.wifiHiddenBadge))) }
            if let password { rows.append(("Password", String(repeating: "•", count: password.count))) }
            return detailStack(rows)

        case .contact(let name, let phone, let email, let org):
            return detailStack([
                ("Name", name),
                ("Phone", phone),
                ("Email", email),
                ("Org", org),
            ].compactMap { label, value in value.map { (label, $0) } })

        case .email(let address):
            return detailStack([("Email", address)])

        case .phone(let number):
            return detailStack([("Phone", number)])

        case .sms(let url):
            return detailStack([("Message", url.absoluteString)])

        case .geo(let coords, _):
            return detailStack([("Coordinates", coords)])

        case .calendarEvent(let title, let location, let start, let end):
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return detailStack([
                ("Title", title),
                ("Location", location),
                ("Start", start.map(df.string)),
                ("End", end.map(df.string)),
            ].compactMap { label, value in value.map { (label, $0) } })

        case .text(let value):
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.borderType = .noBorder
            let textView = NSTextView()
            textView.string = value
            textView.isEditable = false
            textView.font = .systemFont(ofSize: 13)
            scroll.documentView = textView
            return scroll
        }
    }

    private func detailStack(_ rows: [(String, String)]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        for (label, value) in rows {
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
            stack.addArrangedSubview(row)
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
            if canOpenPrivately() { buttons.append(button(L.t(.openPrivately), action: #selector(openPrivately))) }
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

    private func canOpenPrivately() -> Bool {
        guard let defaultBrowser = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) else { return false }
        let name = defaultBrowser.deletingPathExtension().lastPathComponent.lowercased()
        return ["google chrome", "microsoft edge", "brave browser", "vivaldi"].contains(name)
    }

    @objc private func openInBrowser() {
        guard let url = destinationURL() else { showStatus(L.t(.genericOpenFailed)); return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openPrivately() {
        guard let url = destinationURL(), let defaultBrowser = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            showStatus(L.t(.genericOpenFailed)); return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--incognito", "--inprivate"]
        NSWorkspace.shared.open([url], withApplicationAt: defaultBrowser, configuration: config, completionHandler: nil)
    }

    @objc private func copyLink() {
        guard let url = destinationURL() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.absoluteString, forType: .string)
        showStatus(L.t(.copied))
    }

    @objc private func openInApp() {
        if case .social(_, let scheme) = payload.kind, let scheme {
            NSWorkspace.shared.open(scheme)
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
        case .sms(let url): return url
        case .geo(_, let mapsURL): return mapsURL
        default: return nil
        }
    }

    private func fetchAppStoreInfo() {
        guard case .appStore(let url) = payload.kind else { return }
        guard let idRange = url.absoluteString.range(of: "id[0-9]+", options: .regularExpression) else { return }
        let id = String(url.absoluteString[idRange].dropFirst(2))
        guard let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(id)") else { return }
        URLSession.shared.dataTask(with: lookupURL) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first else { return }
            let name = first["trackName"] as? String
            let seller = first["sellerName"] as? String
            let artwork = (first["artworkUrl512"] as? String) ?? (first["artworkUrl100"] as? String)
            DispatchQueue.main.async {
                if let name { self?.titleLabel?.stringValue = name }
                if let seller { self?.subtitleLabel?.stringValue = seller }
                if let artwork, let artworkURL = URL(string: artwork) {
                    URLSession.shared.dataTask(with: artworkURL) { imgData, _, _ in
                        guard let imgData, let image = NSImage(data: imgData) else { return }
                        DispatchQueue.main.async { self?.iconView?.image = image }
                    }.resume()
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

// MARK: - Settings window

final class SettingsWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = L.t(.settingsWindowTitle)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

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
        recorder.onChange = { code, mods in
            store.hotKeyCode = code
            store.hotKeyModifiers = mods
        }
        hotkeyRow.addArrangedSubview(hotkeyLabel)
        hotkeyRow.addArrangedSubview(recorder)
        grid.addArrangedSubview(hotkeyRow)

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

        // Launch at login
        let loginCheckbox = NSButton(checkboxWithTitle: L.t(.launchAtLoginCheckbox), target: self, action: #selector(loginToggled(_:)))
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
        grid.addArrangedSubview(loginCheckbox)
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        SettingsStore.shared.language = AppLanguage.allCases[sender.indexOfSelectedItem]
    }

    @objc private func loginToggled(_ sender: NSButton) {
        LoginItem.setEnabled(sender.state == .on)
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKey = GlobalHotKey()
    private var lens: LensWindowController?
    private var preview: PreviewWindowController?
    private var settings: SettingsWindowController?
    private var registeredHotKey: (code: UInt32, modifiers: UInt32)?
    private var settingsMenuItem: NSMenuItem!
    private var scanMenuItem: NSMenuItem!
    private var quitMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        SettingsStore.shared.enableLoginItemOnFirstRun()
        registerHotKey()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: L.t(.statusItemAccessibility))

        scanMenuItem = NSMenuItem(title: L.t(.scanNowMenuItem), action: #selector(startScan), keyEquivalent: "")
        settingsMenuItem = NSMenuItem(title: L.t(.settingsMenuItem), action: #selector(showSettings), keyEquivalent: "")
        quitMenuItem = NSMenuItem(title: L.t(.quitMenuItem), action: #selector(quit), keyEquivalent: "")
        let menu = NSMenu()
        menu.addItem(scanMenuItem)
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
        let controller = PreviewWindowController(payload: parsed)
        preview = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showSettings() {
        if settings == nil { settings = SettingsWindowController() }
        NSApp.activate(ignoringOtherApps: true)
        settings?.showWindow(nil)
        settings?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

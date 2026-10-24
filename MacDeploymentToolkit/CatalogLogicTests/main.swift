//
//  Standalone checks for catalog mapping, chip fallbacks, and DMG lookup.
//  Not part of the Xcode app target. Run with the swiftc command in the PR notes.
//

import Foundation

func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fail(message)
    }
}

let fixture = """
[
  {"id":"11111111-1111-1111-1111-111111111111","name":"PC Only","category":"Audio","platforms":["pc"],"install_method":"brew","brew_id":"x","enabled":true,"sort_order":1},
  {"id":"22222222-2222-2222-2222-222222222222","name":"Arm Only","category":"Audio","platforms":["mac_apple_silicon"],"install_method":"dmg","download_url":"https://example.com/a.dmg","enabled":true,"detection_method":"app_bundle","detection_value":"/Applications/Interactive Studio.app","sort_order":2},
  {"id":"33333333-3333-3333-3333-333333333333","name":"Intel Only","category":"Networking","platforms":["mac_intel"],"install_method":"zip","download_url":"https://example.com/i.zip?token=abc.def","enabled":true,"sort_order":1},
  {"id":"44444444-4444-4444-4444-444444444444","name":"Both","category":"System","platforms":["mac_apple_silicon","mac_intel"],"install_method":"brew","brew_id":"spotify","brew_type":"cask","enabled":true,"fallback_download_url":"https://example.com/universal.dmg","fallback_download_url_arm":"https://example.com/arm.dmg","fallback_download_url_intel":"https://example.com/intel.pkg","sort_order":3},
  {"id":"55555555-5555-5555-5555-555555555555","name":"Generic Mac","category":"Control","platforms":["mac"],"install_method":"pkg","download_url":"https://example.com/g.pkg","enabled":true,"sort_order":5},
  {"id":"66666666-6666-6666-6666-666666666666","name":"Disabled","category":"Audio","platforms":["mac_intel","mac_apple_silicon"],"install_method":"dmg","download_url":"https://example.com/d.dmg","enabled":false,"sort_order":0},
  {"id":"77777777-7777-7777-7777-777777777777","name":"Audio Test Content","category":"Test Content","platforms":["pc","mac"],"install_method":"extract_to_desktop","download_url":"https://example.com/audio.zip","enabled":true,"detection_method":"none","sort_order":9}
]
""".data(using: .utf8)!

do {
    let arm = try PackageCatalogClient.applications(from: fixture, isAppleSilicon: true)
    let intel = try PackageCatalogClient.applications(from: fixture, isAppleSilicon: false)
    expect(arm.map(\.name) == ["Arm Only", "Both", "Generic Mac", "Audio Test Content"], "arm rows: \(arm.map(\.name))")
    expect(intel.map(\.name) == ["Intel Only", "Both", "Generic Mac", "Audio Test Content"], "intel rows: \(intel.map(\.name))")

    let armOnly = arm[0]
    expect(armOnly.detectionMethod == .appBundle, "detection method")
    expect(armOnly.detectionValue == "/Applications/Interactive Studio.app", "detection value")
    if case .directDownload(let format) = armOnly.installMethod {
        expect(format == .dmg, "arm install format")
    } else {
        fail("arm install method")
    }

    let intelOnly = intel[0]
    expect(intelOnly.effectiveDownloadUrl == "https://example.com/i.zip?token=abc.def", "intel url")
    expect(InstallMethod.InstallerFormat(downloadURL: intelOnly.downloadUrl!) == .zip, "zip extension ignores query")

    let bothArm = arm.first { $0.name == "Both" }!
    let bothIntel = intel.first { $0.name == "Both" }!
    expect(bothArm.fallbackDownloadUrl(forAppleSilicon: true) == "https://example.com/arm.dmg", "arm fallback column")
    expect(bothIntel.fallbackDownloadUrl(forAppleSilicon: false) == "https://example.com/intel.pkg", "intel fallback column")
    expect(bothArm.packageId == "spotify", "brew id")
    if case .homebrew(let type) = bothArm.installMethod {
        expect(type == .cask, "brew type")
    } else {
        fail("both should be homebrew")
    }

    let sharedOnly = ApplicationDefinition(
        name: "Shared",
        category: .system,
        installMethod: .homebrew(type: .cask),
        fallbackDownloadUrl: "https://example.com/universal.dmg"
    )
    expect(sharedOnly.fallbackDownloadUrl(forAppleSilicon: true) == "https://example.com/universal.dmg", "shared fallback on arm")
    expect(sharedOnly.fallbackDownloadUrl(forAppleSilicon: false) == "https://example.com/universal.dmg", "shared fallback on intel")

    let tests = arm.first { $0.name == "Audio Test Content" }!
    if case .custom(let handler) = tests.installMethod {
        expect(handler == "audiotestcontent", "test content handler")
    } else {
        fail("test content method")
    }
    expect(tests.detectionMethod == .skip, "none detection")
} catch {
    fail("fixture decode: \(error)")
}

let nested = DMGInstallerLocator.locate([
    DMGItem(name: ".DS_Store", isDirectory: false, children: []),
    DMGItem(name: "Interactive Studio", isDirectory: true, children: [
        DMGItem(name: "._junk.app", isDirectory: true, children: []),
        DMGItem(name: "Interactive Studio.app", isDirectory: true, children: [])
    ])
])
expect(nested?.kind == .app, "nested dmg kind")
expect(nested?.pathComponents == ["Interactive Studio", "Interactive Studio.app"], "nested dmg path \(String(describing: nested?.pathComponents))")

let pkgWins = DMGInstallerLocator.locate([
    DMGItem(name: "Setup.app", isDirectory: true, children: []),
    DMGItem(name: "Install.pkg", isDirectory: false, children: [])
])
expect(pkgWins?.kind == .pkg && pkgWins?.pathComponents == ["Install.pkg"], "pkg preferred at top level")

let nestedPkg = DMGInstallerLocator.locate([
    DMGItem(name: "Payload", isDirectory: true, children: [
        DMGItem(name: "Driver.pkg", isDirectory: false, children: []),
        DMGItem(name: "Helper.app", isDirectory: true, children: [])
    ])
])
expect(nestedPkg?.kind == .pkg && nestedPkg?.pathComponents == ["Payload", "Driver.pkg"], "nested pkg preferred over nested app")

expect(DMGInstallerLocator.locate([
    DMGItem(name: "__MACOSX", isDirectory: true, children: [
        DMGItem(name: "Hidden.app", isDirectory: true, children: [])
    ])
]) == nil, "macOS metadata is ignored")

let keyParts = PackageCatalogClient.anonKey.split(separator: ".")
expect(keyParts.count == 3, "catalog key shape")
var payload = keyParts[1]
    .replacingOccurrences(of: "-", with: "+")
    .replacingOccurrences(of: "_", with: "/")
while payload.count % 4 != 0 { payload += "=" }
guard let payloadData = Data(base64Encoded: payload),
      let json = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
      let role = json["role"] as? String else {
    fail("catalog key payload")
}
expect(role == "anon", "catalog key role is \(role)")

do {
    let remoteArm = try await PackageCatalogClient.fetchEnabledMacPackages(isAppleSilicon: true)
    let remoteIntel = try await PackageCatalogClient.fetchEnabledMacPackages(isAppleSilicon: false)
    expect(!remoteArm.isEmpty && !remoteIntel.isEmpty, "remote catalog empty")
    expect(remoteArm.filter { $0.name == "Angry IP Scanner" }.count == 1, "one arm Angry IP row")
    expect(remoteIntel.filter { $0.name == "Angry IP Scanner" }.count == 1, "one intel Angry IP row")
    expect(!remoteArm.contains { $0.name == "PTP Track Hound" }, "PTP is intel-only")
    expect(remoteIntel.contains { $0.name == "PTP Track Hound" }, "PTP missing on intel")

    let shure = remoteArm.first { $0.name == "Shure Update Utility" }
    expect(shure?.version == "2.8.16.10", "shure version \(shure?.version ?? "nil")")
    expect(shure?.downloadUrl?.contains("shure.com") == true, "shure url should come from the table")

    let cue = remoteArm.first { $0.name == "CueServer Studio" }
    expect(cue?.detectionValue == "/Applications/Interactive Studio.app", "cueserver detection \(cue?.detectionValue ?? "nil")")
    expect(cue?.installMethod == .directDownload(format: .dmg), "cueserver format")

    let reaper = remoteArm.first { $0.name == "Reaper" }
    expect(InstallMethod.InstallerFormat(downloadURL: reaper?.effectiveFallbackDownloadUrl ?? "") == .dmg, "reaper fallback dmg")

    let dante = remoteArm.first { $0.name == "Dante Controller" }
    expect(dante?.packageId == "dante-controller", "dante brew id")
    expect(dante?.effectiveFallbackDownloadUrl == nil, "dante has no fallback until the new columns are filled")

    let sacn = remoteArm.first { $0.name == "sACN View" }
    expect(sacn?.version == "3.1.0", "sacn version \(sacn?.version ?? "nil")")

    expect(remoteArm.contains { $0.name == "Netgear Engage" }, "remote-only app missing")
    expect(remoteArm.allSatisfy { $0.detectionMethod != nil || $0.name.isEmpty }, "remote rows should carry detection")
    print("Remote catalog: \(remoteArm.count) Apple Silicon apps, \(remoteIntel.count) Intel apps")
} catch {
    fail("live catalog fetch: \(error)")
}

print("OK")

#!/usr/bin/swift

import Foundation

// MARK: - Configuration

let projectName = "FaceLivenessTest"
let scheme = "FaceLivenessTest"
let configuration = "Release"
let exportPath = "../build"
let archiveFolder = "../archives"
let archivePath = "\(archiveFolder)/\(projectName).xcarchive"
let exportOptionsPlist = "\(exportPath)/exportOptions.plist"
let displayName = "FaceLivenessTest"

// read script arguments
let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("❌ Error: Missing arguments.")
    print("Usage: swift build_ota.swift <deployURL> [ipaName]")
    exit(1)
}

let deployURL: String = arguments[1]
let plistURL = "\(deployURL)/manifest.plist"

let ipaName =  if arguments.count > 2 { arguments[2] } else { "\(projectName).ipa"}

let ipaURL = "\(deployURL)/\(ipaName)"
let otaHTMLPath = "\(exportPath)/index.html"
let plistPath = "\(exportPath)/manifest.plist"

let archiveIpaPath = "\(exportPath)/\(projectName).ipa"
let ipaPath = "\(exportPath)/\(ipaName)"
// MARK: - Utility Functions

@discardableResult
func shell(_ command: String) -> String {
    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", command]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.launch()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: outputData, encoding: .utf8) ?? ""
}

// MARK: - Build and Export Process
print("🛠 Creating build directory...")
shell("mkdir -p \(exportPath)")
shell("mkdir -p \(archiveFolder)")


print("📝 Generating exportOptions.plist...")
let exportOptionsTemplatePath = "exportOptions_template.plist"
let exportOptions = try String(contentsOfFile: exportOptionsTemplatePath, encoding: .utf8) 
try exportOptions.write(toFile: exportOptionsPlist, atomically: true, encoding: .utf8)

let skipBuild = arguments.contains("--skip-build")

if skipBuild {
    print("⏭ Skipping build process.")
} else {
    print("📦 Building and archiving the app...")
    let buildCommand = """
    xcodebuild -project ../\(projectName).xcodeproj \
        -scheme \(scheme) \
        -configuration \(configuration) \
        -sdk iphoneos \
        -archivePath \(archivePath) \
        -allowProvisioningUpdates \
        archive
    """
    let buildOutput = shell(buildCommand)
    print(buildOutput)

    print("📤 Exporting IPA...")
    let exportCommand = """
    xcodebuild -exportArchive \
        -archivePath \(archivePath) \
        -exportPath \(exportPath) \
        -exportOptionsPlist \(exportOptionsPlist) \
        -allowProvisioningUpdates
    """
    let exportOutput = shell(exportCommand)
    print(exportOutput)

    // Check if IPA file exists
    guard FileManager.default.fileExists(atPath: archiveIpaPath) else {
        print("❌ Error: IPA file was not created.")
        exit(1)
    }

    shell("mv \(archiveIpaPath) \(ipaPath)")

    print("✅ IPA file created at: \(ipaPath)")
}

print("🔍 Reading bundle identifier from IPA...")
let ipaInfoCommand = "unzip -p \(ipaPath) 'Payload/*.app/Info.plist' | plutil -convert xml1 -o - -"
let ipaInfoPlist = shell(ipaInfoCommand)

guard let data = ipaInfoPlist.data(using: .utf8),
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
    let bundleIdentifier = plist["CFBundleIdentifier"] as? String else {
    print("❌ Error: Could not read bundle identifier from IPA.")
    exit(1)
}

print("✅ Bundle identifier: \(bundleIdentifier)")

// MARK: - Generate OTA Files
print("✅ Display name: \(displayName)")

print("📝 Generating manifest.plist...")
let manifestTemplatePath = "manifest_template.plist"
let manifestTemplate = try String(contentsOfFile: manifestTemplatePath, encoding: .utf8) 

let manifestPlist = manifestTemplate
    .replacingOccurrences(of: "$(bundleIdentifier)", with: bundleIdentifier)
    .replacingOccurrences(of: "$(ipaURL)", with: ipaURL)
    .replacingOccurrences(of: "$(displayName)", with: displayName)

try manifestPlist.write(toFile: plistPath, atomically: true, encoding: .utf8)

print("📝 Generating OTA installation page...")

let otaTemplatePath = "ota_template.html"
let otaTemplate = try String(contentsOfFile: otaTemplatePath, encoding: .utf8)

let otaHTML = otaTemplate
    .replacingOccurrences(of: "$(displayName)", with: displayName)
    .replacingOccurrences(of: "$(plistURL)", with: plistURL)

try otaHTML.write(toFile: otaHTMLPath, atomically: true, encoding: .utf8)

shell("swift generate_qr.swift \(deployURL) \(exportPath)/qr.png")
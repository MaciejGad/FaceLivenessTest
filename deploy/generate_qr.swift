#!/usr/bin/swift

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

func generateQRCode(from string: String, outputFilePath: String) {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    guard let data = string.data(using: .ascii) else {
        print("Invalid input string")
        return
    }
    
    filter.message = data
    
    if let qrCodeImage = filter.outputImage {
        let transformedImage = qrCodeImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        
        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: transformedImage.extent.width, height: transformedImage.extent.height))
            saveImage(nsImage, to: outputFilePath)
            print("QR Code saved at: \(outputFilePath)")
        }
    }
}

func saveImage(_ image: NSImage, to filePath: String) {
    guard let tiffData = image.tiffRepresentation else {
        print("Failed to get TIFF data")
        return
    }
    
    guard let bitmap = NSBitmapImageRep(data: tiffData) else {
        print("Failed to create bitmap")
        return
    }
    
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to convert image to PNG")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: filePath))
    } catch {
        print("File write error: \(error)")
    }
}

// Script usage
let arguments = CommandLine.arguments
if arguments.count < 3 {
    print("Usage: \(arguments[0]) <URL> <Output Path>")
    exit(1)
}

let url = arguments[1]
let outputFilePath = arguments[2].expandingTildeInPath
generateQRCode(from: url, outputFilePath: outputFilePath)

// Extension for expanding tilde in paths
extension String {
    var expandingTildeInPath: String {
        return (self as NSString).expandingTildeInPath
    }
}

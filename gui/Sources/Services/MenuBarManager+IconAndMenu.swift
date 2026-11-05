import Foundation
import AppKit

@MainActor
extension MenuBarManager {
    public func createMenuBarIcon(style: MenuBarIconStyle = .matchAppIcon) -> NSImage {
        let ptSize: CGFloat = 18
        let size = NSSize(width: ptSize, height: ptSize)

        switch style {
        case .matchAppIcon:
            let resName = viewModel?.iconAppearanceMode.resourceName ?? "AppIcon-Default"
            return createIconFromAppIcon(name: resName, fallbackName: "AppIcon", ptSize: ptSize)

        case .symbol:
            let pngCandidates = [
                Bundle.main.url(forResource: "MenuBarIcon-Symbol@2x", withExtension: "png"),
                Bundle.main.url(forResource: "MenuBarIcon-Symbol", withExtension: "png")
            ].compactMap { $0 }

            for url in pngCandidates {
                if let img = NSImage(contentsOf: url) {
                    img.size = size
                    img.isTemplate = true
                    return img
                }
            }

            let svgCandidates = [
                Bundle.main.url(forResource: "NxLauncher_Logo", withExtension: "svg"),
                Bundle.main.url(forResource: "Vector", withExtension: "svg"),
                Bundle.main.url(forResource: "AppLogo-Symbol", withExtension: "svg")
            ].compactMap { $0 }

            for url in svgCandidates {
                if let svg = NSImage(contentsOf: url) {
                    return rasterizeSymbol(svg: svg, ptSize: ptSize)
                }
            }

            let fsPaths = [
                "nxnative/gui/Resources/MenuBarIcon-Symbol@2x.png",
                "nxnative/gui/Resources/MenuBarIcon-Symbol.png",
                "gui/Resources/MenuBarIcon-Symbol.png",
                "NxLauncher_Logo.svg",
                "nxnative/gui/Resources/NxLauncher_Logo.svg",
                "Vector.svg",
                "nxnative/gui/Resources/Vector.svg"
            ]
            for p in fsPaths where FileManager.default.fileExists(atPath: p) {
                if p.hasSuffix(".svg") {
                    if let svg = NSImage(contentsOfFile: p) {
                        return rasterizeSymbol(svg: svg, ptSize: ptSize)
                    }
                } else if let img = NSImage(contentsOfFile: p) {
                    img.size = size
                    img.isTemplate = true
                    return img
                }
            }

            if let symbolImage = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "NxNative") {
                symbolImage.size = size
                symbolImage.isTemplate = true
                return symbolImage
            }

            let fallback = NSImage(size: size)
            fallback.isTemplate = true
            return fallback

        case .dark:
            return createIconFromAppIcon(name: "AppIcon-Dark", ptSize: ptSize)

        case .lightColor:
            return createIconFromAppIcon(name: "AppIcon-Default", fallbackName: "AppIcon", ptSize: ptSize)
        }
    }

    private func rasterizeSymbol(svg: NSImage, ptSize: CGFloat) -> NSImage {
        let size = NSSize(width: ptSize, height: ptSize)
        let scale: CGFloat = 2.0
        let pxSize = Int(ptSize * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxSize,
            pixelsHigh: pxSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            let img = NSImage(size: size)
            img.isTemplate = true
            return img
        }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = ctx
        ctx?.cgContext.clear(CGRect(x: 0, y: 0, width: CGFloat(pxSize), height: CGFloat(pxSize)))
        ctx?.imageInterpolation = .high
        ctx?.shouldAntialias = true

        let targetH: CGFloat = ptSize - 3.0
        let svgSize = svg.size
        let aspect = max(svgSize.width, 1) / max(svgSize.height, 1)
        var drawHeight = targetH
        var drawWidth = drawHeight * aspect
        if drawWidth > ptSize - 2.0 {
            drawWidth = ptSize - 2.0
            drawHeight = drawWidth / aspect
        }
        let originX = (ptSize - drawWidth) / 2.0
        let originY = (ptSize - drawHeight) / 2.0
        let drawRect = NSRect(x: originX, y: originY, width: drawWidth, height: drawHeight)
        svg.draw(in: drawRect, from: NSRect(origin: .zero, size: svgSize), operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        let outImg = NSImage(size: size)
        outImg.addRepresentation(rep)
        outImg.isTemplate = true
        return outImg
    }

    private func createIconFromAppIcon(name: String, fallbackName: String? = nil, ptSize: CGFloat) -> NSImage {
        let size = NSSize(width: ptSize, height: ptSize)
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "png"),
            Bundle.main.url(forResource: name, withExtension: "icns"),
            fallbackName.flatMap { Bundle.main.url(forResource: $0, withExtension: "png") },
            fallbackName.flatMap { Bundle.main.url(forResource: $0, withExtension: "icns") }
        ].compactMap { $0 }

        var sourceImage: NSImage? = nil
        for url in candidates {
            if let img = NSImage(contentsOf: url) {
                sourceImage = img
                break
            }
        }

        if sourceImage == nil {
            let fsPaths = [
                "nxnative/gui/Resources/\(name).png",
                "gui/Resources/\(name).png",
                "Resources/\(name).png",
                fallbackName.map { "nxnative/gui/Resources/\($0).png" },
                fallbackName.map { "gui/Resources/\($0).png" }
            ].compactMap { $0 }
            for p in fsPaths where FileManager.default.fileExists(atPath: p) {
                if let img = NSImage(contentsOfFile: p) {
                    sourceImage = img
                    break
                }
            }
        }

        guard let src = sourceImage else {
            let fallback = NSImage(size: size)
            fallback.isTemplate = false
            return fallback
        }

        let scale: CGFloat = 2.0
        let pxSize = Int(ptSize * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxSize,
            pixelsHigh: pxSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            src.size = size
            src.isTemplate = false
            return src
        }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = ctx
        ctx?.cgContext.clear(CGRect(x: 0, y: 0, width: CGFloat(pxSize), height: CGFloat(pxSize)))

        let drawRect = NSRect(x: 0.5, y: 0.5, width: ptSize - 1.0, height: ptSize - 1.0)
        src.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        let outImg = NSImage(size: size)
        outImg.addRepresentation(rep)
        outImg.isTemplate = false
        return outImg
    }
}

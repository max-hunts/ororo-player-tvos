//
//  UIImageView+Remote.swift
//  Ororo-Kit
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import UIKit
import ImageIO

/// Decoded images shared by every image view, keyed by URL (and target size
/// when downsampled). Bounded by an approximate decoded-bitmap byte cost so a
/// long scroll through the catalog doesn't grow memory without limit.
private let imageCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.totalCostLimit = 100 * 1024 * 1024
    return cache
}()

public extension UIImageView {

    // MARK: - Public interface
    /// Loads and displays a remote image.
    ///
    /// Pass `maxPixelSize` for grid thumbnails: the image is then decoded and
    /// downsampled off the main thread. Without it, `UIImage` defers JPEG
    /// decoding to the first on-screen render — a row of freshly appearing
    /// posters decoding on the main thread drops frames while scrolling.
    func set(url: URL,
             placeholder: UIImage? = nil,
             maxPixelSize: CGFloat? = nil,
             transform: ((UIImage) -> UIImage)? = nil) {
        dataTask?.cancel()

        let cacheKey: NSString
        if let maxPixelSize = maxPixelSize {
            cacheKey = "\(url.absoluteString)#\(Int(maxPixelSize))" as NSString
        } else {
            cacheKey = url.absoluteString as NSString
        }

        // The cache stores the displayed (downsampled, post-transform) image.
        if let cached = imageCache.object(forKey: cacheKey) {
            image = cached
            return
        }

        image = placeholder
        // Remember which url this view currently wants: a slow response for a
        // previous url must not overwrite the image after cell reuse.
        currentUrl = url
        dataTask = URLSession.shared.dataTask(with: url) { [weak self] (data, _, _) in
            guard let data = data else { return }

            var decoded: UIImage?
            if let maxPixelSize = maxPixelSize {
                decoded = UIImageView.downsampledImage(from: data,
                                                       maxPixelSize: maxPixelSize)
            } else {
                decoded = UIImage(data: data)
            }
            guard var image = decoded else { return }

            // Applied off the main queue, before dispatching back.
            if let transform = transform {
                image = transform(image)
            }
            let pixels = image.size.width * image.size.height * image.scale * image.scale
            imageCache.setObject(image, forKey: cacheKey, cost: Int(pixels * 4))
            DispatchQueue.main.async(execute: {
                guard let self = self, self.currentUrl == url else { return }
                self.image = image
            })
        }
        dataTask?.resume()
    }

    func stopLoading() {
        dataTask?.cancel()
    }

    // MARK: - Inner type
    private struct AssociatedKeys {
        static var DescriptiveName = "data_task_associated_key"
        static var CurrentUrl = "current_url_associated_key"
    }

    // MARK: - Private members
    /// Decodes immediately (still on the calling background queue) and caps
    /// the longest side, so the main thread only draws a ready bitmap.
    private static func downsampledImage(from data: Data,
                                         maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private var dataTask: URLSessionDataTask? {
        get {
            return objc_getAssociatedObject(self,
                                            &AssociatedKeys.DescriptiveName) as? URLSessionDataTask
        }
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.DescriptiveName,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var currentUrl: URL? {
        get {
            return objc_getAssociatedObject(self,
                                            &AssociatedKeys.CurrentUrl) as? URL
        }
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.CurrentUrl,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

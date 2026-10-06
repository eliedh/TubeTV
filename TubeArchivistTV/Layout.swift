//
//  Layout.swift
//  TubeTV
//

import SwiftUI
import UIKit

/// Single place for the per-device sizing that used to be repeated as
/// `#if os(tvOS) … #else if UIDevice.current.userInterfaceIdiom == .pad …` in every view.
enum Layout {
    enum DeviceClass {
        case tv, pad, phone
    }

    static var deviceClass: DeviceClass {
        #if os(tvOS)
        return .tv
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #endif
    }

    /// Picks the value for the current device class
    static func value<T>(tv: T, pad: T, phone: T) -> T {
        switch deviceClass {
        case .tv: return tv
        case .pad: return pad
        case .phone: return phone
        }
    }

    // MARK: - Video Grid

    static var gridColumns: [GridItem] {
        let count = value(tv: 3, pad: 3, phone: 2)
        let spacing: CGFloat = value(tv: 20, pad: 16, phone: 12)
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }

    static var gridSpacing: CGFloat { value(tv: 30, pad: 24, phone: 16) }

    /// Vertical spacing between the sections of a screen (controls, banners, grid)
    static var sectionSpacing: CGFloat { value(tv: 20, pad: 18, phone: 16) }

    /// How many cards from the end of the list should trigger loading the next page
    static var prefetchThreshold: Int { value(tv: 6, pad: 6, phone: 4) }

    // MARK: - Video Card

    static var thumbnailSize: CGSize {
        value(tv: CGSize(width: 400, height: 225),
              pad: CGSize(width: 240, height: 135),
              phone: CGSize(width: 160, height: 90))
    }

    static var cardSpacing: CGFloat { value(tv: 12, pad: 10, phone: 8) }
    static var cardPadding: CGFloat { value(tv: 16, pad: 12, phone: 8) }
    static var cornerRadius: CGFloat { value(tv: 16, pad: 14, phone: 12) }
    static var shadowRadius: CGFloat { value(tv: 8, pad: 6, phone: 4) }
    static var cardTitleFont: Font { value(tv: .headline, pad: .subheadline, phone: .caption) }
    static var cardTitleLineLimit: Int { value(tv: 2, pad: 2, phone: 3) }
}

import Foundation

#if XCODE_RELEASE_TARGET
extension Bundle {
    // Xcode app archives load packaged resources from Bundle.main; SwiftPM uses Bundle.module.
    static var module: Bundle {
        .main
    }
}
#endif

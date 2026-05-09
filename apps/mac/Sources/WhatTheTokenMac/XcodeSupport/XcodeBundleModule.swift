import Foundation

#if XCODE_RELEASE_TARGET
extension Bundle {
    static var module: Bundle {
        .main
    }
}
#endif

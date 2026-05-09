import Foundation
import Testing

func macPackageRootURL(filePath: String = #filePath) -> URL {
    URL(fileURLWithPath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func macRepositoryRootURL(filePath: String = #filePath) -> URL {
    macPackageRootURL(filePath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func macFileContents(_ relativePath: String, filePath: String = #filePath) throws -> String {
    let url = macPackageRootURL(filePath: filePath).appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

func repositoryFileContents(_ relativePath: String, filePath: String = #filePath) throws -> String {
    let url = macRepositoryRootURL(filePath: filePath).appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

func packagingInfoPlist(filePath: String = #filePath) throws -> [String: Any] {
    let url = macPackageRootURL(filePath: filePath).appendingPathComponent("Packaging/Info.plist")
    let data = try Data(contentsOf: url)
    return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}

func packagingPlist(_ relativePath: String, filePath: String = #filePath) throws -> [String: Any] {
    let url = macPackageRootURL(filePath: filePath).appendingPathComponent(relativePath)
    let data = try Data(contentsOf: url)
    return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}

func decodedJSONFile<T: Decodable>(
    _ relativePath: String,
    as type: T.Type,
    filePath: String = #filePath
) throws -> T {
    let url = macPackageRootURL(filePath: filePath).appendingPathComponent(relativePath)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

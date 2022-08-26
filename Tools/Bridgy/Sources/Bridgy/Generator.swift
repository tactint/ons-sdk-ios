import Foundation

internal extension String {
    var pathExtension: String {
        return (self as NSString).pathExtension
    }
    
    var realpath: String? {
        guard let rv = Darwin.realpath(self, nil) else { return nil }
        defer { free(rv) }
        guard let rvv = String(validatingUTF8: rv) else { return nil }
        return rvv
    }
}

internal extension NSRegularExpression {
    @inlinable
    func matches(_ str: String) -> Bool {
        return firstMatch(in: str, options: [], range: NSRange(str.startIndex..<str.endIndex, in: str)) != nil
    }
}

public enum GeneratorError: Error {
    case configurationError
    case invalidIgnoreRegexp
    case notAFolder
    case enumerationError
    case couldNotGetRealPath
    case encodingError
    case writeError
}

let bridgingHeaderPrefix = """
//
//  This bridging header has been automatically generated by Bridgy
//  DO NOT EDIT MANUALLY.
//  USE THE TOOL TO REGENERATE IF YOU NEED TO ADD/REMOVE HEADERS.
//


"""

public class Generator {
    var basePath: String
    var outputDir: String
    var config: Config
    
    init(basePath: String, config: Config) throws {
        self.basePath = basePath
        self.config = config
        self.outputDir = "" // Need to set a value before calling a method on self
        guard let outputDir = absolutePath(for: config.outputDir) else {
            print("Could not use output directory")
            throw GeneratorError.couldNotGetRealPath
        }
        self.outputDir = outputDir
    }
     
    func generate() throws {
        print("Base working path: \(basePath)")
        
        print("Output directory: \(outputDir)")
        
        guard let baseSearchPath = absolutePath(for: config.basePath) else {
            print("Could not use output directory")
            throw GeneratorError.couldNotGetRealPath
        }
        
        print("Base header search directory: \(baseSearchPath)")
        print("----------")
        print("Generating headers..")
        
        let headersToGenerate = config.headers
        
        var bridgingHeaderContents: [String: String] = [:]
        
        do {
            for bridgingHeaderName in headersToGenerate.keys {
                if let generatorConfig = headersToGenerate[bridgingHeaderName] {
                    print("Generating \(bridgingHeaderName)...")
                    guard let path = absolutePath(for: generatorConfig.path, withBasePath: baseSearchPath) else {
                        throw GeneratorError.couldNotGetRealPath
                    }
                    print("Scanning \(path)")
                    let headersToInclude = try headerFilenames(atPath: path, scanRecursively: generatorConfig.recursive, ignoredNames: generatorConfig.ignoredNames)
                    bridgingHeaderContents[bridgingHeaderName] = self.makeBridgingHeaderContent(name: bridgingHeaderName, frameworkName: generatorConfig.frameworkName, headers: headersToInclude)
                }
            }
        } catch {
            print("Error while generating: \(error). No files have been changed")
            throw error
        }
        
        // Write the output files
        for bridgingHeader in bridgingHeaderContents.keys {
            print("Writing \(bridgingHeader)")
            if let content = bridgingHeaderContents[bridgingHeader] {
                do {
                    try writeBridgingHeader(name: bridgingHeader, content: content)
                } catch {
                    print("Error while writing \(bridgingHeader): \(error)")
                    throw error
                }
            }
        }
        
    }
    
    // Gets the absolute path for a relative one.
    // If the path is already absolute, it will returned as is
    func absolutePath(for path: String, withBasePath bp: String) -> String? {
        let nsPath = path as NSString;
        if nsPath.isAbsolutePath {
            return path
        }
        return (bp as NSString).appendingPathComponent(path).realpath
    }

    func absolutePath(for path: String) -> String? {
        absolutePath(for: path, withBasePath: self.basePath)
    }
    
    // Returns the header filenames for a given path
    // Only the filenames are returned because headers don't need to be referenced by path, only by filename
    // Can scan recursively
    func headerFilenames(atPath path: String, scanRecursively: Bool, ignoredNames: String?) throws -> [String] {
        let ignoredNamesRegexp: NSRegularExpression?
        if let ignoredNames = ignoredNames {
            do {
                ignoredNamesRegexp = try NSRegularExpression(pattern: ignoredNames, options: [])
            } catch {
                throw GeneratorError.invalidIgnoreRegexp
            }
        } else {
            ignoredNamesRegexp = nil
        }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath:path, isDirectory:&isDir) || !isDir.boolValue {
            throw GeneratorError.notAFolder
        }
        
        guard let enumerator = fm.enumerator(atPath: path) else {
            throw GeneratorError.enumerationError
        }
        
        var results: [String] = []
        
        while let filepath = enumerator.nextObject() as? String {
            if !scanRecursively {
                enumerator.skipDescendents()
            }
            if let attrs = enumerator.fileAttributes,
                let type = attrs[FileAttributeKey.type] as? FileAttributeType,
                type != FileAttributeType.typeRegular {
                continue
            }
            
            if filepath.pathExtension.caseInsensitiveCompare("h") != .orderedSame {
                continue
            }

            let filename = (filepath as NSString).lastPathComponent
            if ignoredNamesRegexp?.matches(filename) ?? false {
                continue
            } 
            results.append(filename)
        }
        
        return results
    }
    
    func makeBridgingHeaderContent(name: String, frameworkName: String?, headers: [String]) -> String {
        var content = "//  \(name)\n" + bridgingHeaderPrefix
        
        for header in headers {
            if header == name {
                continue
            }
            
            if let frameworkName = frameworkName {
                content.append("#import <\(frameworkName)/\(header)>\n")
            } else {
                content.append("#import \"\(header)\"\n")
            }
        }
        
        return content
    }
    
    func writeBridgingHeader(name: String, content: String) throws {
        let filePath = (self.outputDir as NSString).appendingPathComponent(name)
        guard let data = content.data(using: .utf8) else { throw GeneratorError.encodingError }
        if !(data as NSData).write(toFile: filePath, atomically: true) {
            throw GeneratorError.writeError
        }
    }
}
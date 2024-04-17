// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "ONSBatch",
    platforms: [
        .iOS(.v10)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ONSBatch",
            targets: ["ONSBatch"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        .binaryTarget(
            name: "ONSBatch",
            url: "https://ons.pfs.gdn/assets/ios/spm/BatchSDK-ios_spm-xcframework-1.21.2.zip",
            checksum: "5caa61a570d8317f4f5a75e4325c2bfcbc5f9b98349bffd5c2fc21375755da25"
        )
    ]
)
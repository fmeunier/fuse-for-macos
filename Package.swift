// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "FuseGenerator",
  products: [
    .library(
      name: "FuseGenerator",
      targets: ["FuseGenerator"]
    ),
  ],
  targets: [
    .binaryTarget(
      name: "FuseGenerator",
      url: "https://github.com/fmeunier/FuseGenerator/releases/download/fuse-generator-1.5.0-rc3/FuseGenerator-1.5.0-rc3.qlgenerator.zip",
      checksum: "8ebbd7609cfb5a5d41aeee14c62d94fdcf8a5b5416e7db41b42539ecda8dcd9e"
    ),
  ]
)

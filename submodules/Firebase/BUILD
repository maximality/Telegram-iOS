load("@build_bazel_rules_apple//apple:apple.bzl", "apple_static_framework_import", "apple_dynamic_framework_import")

filegroup(
    name = "GoogleService",
    srcs = glob([
        "GoogleService-Info.plist"
    ]),
    visibility = [
        "//visibility:public"
    ]
)

# https://github.com/firebase/firebase-ios-sdk/releases
# Firestore
# version 7.6.0

apple_static_framework_import(
    name = "leveldb-library",
    framework_imports = glob([
        "Libraries/leveldb-library.framework/**",
    ], exclude = [
        "Libraries/leveldb-library.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "gRPC-Core",
    framework_imports = glob([
        "Libraries/gRPC-Core.framework/**",
    ], exclude = [
        "Libraries/gRPC-Core.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "gRPC-C++",
    framework_imports = glob([
        "Libraries/gRPC-C++.framework/**",
    ], exclude = [
        "Libraries/gRPC-C++.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "abseil",
    framework_imports = glob([
        "Libraries/abseil.framework/**",
    ], exclude = [
        "Libraries/abseil.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_dynamic_framework_import(
    name = "BoringSSL-GRPC",
    framework_imports = glob([
        "Libraries/openssl_grpc.framework/**",
    ], exclude = [
        "Libraries/openssl_grpc.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "Firestore",
    framework_imports = glob([
        "Libraries/FirebaseFirestore.framework/**",
    ], exclude = [
        "Libraries/FirebaseFirestore.framework/Modules/module.modulemap",
    ]),
    deps = [
        ":BoringSSL-GRPC",
        ":abseil",
        ":gRPC-C++",
        ":gRPC-Core",
        ":leveldb-library",
        ":Analytics",
    ],
    visibility = [
      "//visibility:public",
    ],
    sdk_frameworks = [
        "Foundation",
        "CoreTelephony",
        "SystemConfiguration",
        "UIKit",
    ],
)

# Crashlytics

apple_static_framework_import(
    name = "Crashlytics",
    framework_imports = glob([
        "Libraries/FirebaseCrashlytics.framework/**",
    ], exclude = [
        "Libraries/FirebaseCrashlytics.framework/Modules/module.modulemap",
    ]),
    deps = [
        ":Analytics",
    ],
    visibility = [
      "//visibility:public",
    ],
    sdk_frameworks = [
        "Foundation",
        "CoreTelephony",
        "Security",
        "SystemConfiguration",
        "UIKit",
    ],
)

# Analytics

apple_static_framework_import(
    name = "Core",
    framework_imports = glob([
        "Libraries/FirebaseCore.framework/**",
    ], exclude = [
        "Libraries/FirebaseCore.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "CoreDiagnostics",
    framework_imports = glob([
        "Libraries/FirebaseCoreDiagnostics.framework/**",
    ], exclude = [
        "Libraries/FirebaseCoreDiagnostics.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "Installations",
    framework_imports = glob([
        "Libraries/FirebaseInstallations.framework/**",
    ], exclude = [
        "Libraries/FirebaseInstallations.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "GoogleAppMeasurement",
    framework_imports = glob([
        "Libraries/GoogleAppMeasurement.framework/**",
    ], exclude = [
        "Libraries/GoogleAppMeasurement.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "GoogleDataTransport",
    framework_imports = glob([
        "Libraries/GoogleDataTransport.framework/**",
    ], exclude = [
        "Libraries/GoogleDataTransport.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "GoogleUtilities",
    framework_imports = glob([
        "Libraries/GoogleUtilities.framework/**",
    ], exclude = [
        "Libraries/GoogleUtilities.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "PromisesObjC",
    framework_imports = glob([
        "Libraries/PromisesObjC.framework/**",
    ], exclude = [
        "Libraries/PromisesObjC.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "nanopb",
    framework_imports = glob([
        "Libraries/nanopb.framework/**",
    ], exclude = [
        "Libraries/nanopb.framework/Modules/module.modulemap",
    ]),
    visibility = [
      "//visibility:public",
    ]
)

apple_static_framework_import(
    name = "Analytics",
    framework_imports = glob([
        "Libraries/FirebaseAnalytics.framework/**",
    ], exclude = [
        "Libraries/FirebaseAnalytics.framework/Modules/module.modulemap",
    ]),
    deps = [
        ":nanopb",
        ":PromisesObjC",
        ":GoogleUtilities",
        ":GoogleDataTransport",
        ":GoogleAppMeasurement",
        ":Installations",
        ":CoreDiagnostics",
        ":Core",
    ],
    visibility = [
      "//visibility:public",
    ],
    sdk_frameworks = [
        "Foundation",
        "CoreTelephony",
        "Security",
        "SystemConfiguration",
        "UIKit",
    ],
)

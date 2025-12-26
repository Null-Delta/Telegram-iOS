load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
)

filegroup(
    name = "DisplaySources",
    srcs = glob([
        "Metal/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "DisplayBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.Display</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>Display</string>
    """
)

apple_resource_bundle(
    name = "DisplayBundle",
    infoplists = [
        ":DisplayBundleInfoPlist",
    ],
    resources = [
        ":DisplaySources",
    ],
)

swift_library(
    name = "Display",
    module_name = "Display",
    srcs = glob([
        "Source/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":DisplayBundle",
    ],
    deps = [
    	"//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
    	"//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/AppBundle:AppBundle",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Markdown:Markdown",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)

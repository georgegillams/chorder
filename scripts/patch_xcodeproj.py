#!/usr/bin/env python3
"""Patch Chorder.xcodeproj for ChorderCore + ChorderInputMethod targets."""
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "Chorder.xcodeproj/project.pbxproj"


def gid() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> None:
    c = PBX.read_text()

    PKG_REF = gid()
    PKG_CHORDER, PKG_TESTS, PKG_IMK = gid(), gid(), gid()
    IMK_TARGET = gid()
    IMK_SOURCES, IMK_FRAMEWORKS, IMK_RESOURCES = gid(), gid(), gid()
    IMK_PRODUCT = gid()
    IMK_CFG_LIST, IMK_DBG, IMK_REL = gid(), gid(), gid()
    IMK_DEP, IMK_PROXY = gid(), gid()
    COPY_PHASE, COPY_FILE = gid(), gid()
    FW_CHORDER, FW_TESTS, FW_IMK = gid(), gid(), gid()
    FW_IMK_KIT, FW_IMK_KIT_REF = gid(), gid()

    app_files = [
        ("IMKCHORDUI01", "Chord+UI.swift", "IMKCHORDUI02", "models"),
        ("IMKLEGTO01", "LegacyTextOutputter.swift", "IMKLEGTO02", "services"),
        ("IMKREG01", "AppSettingsChordRegistry.swift", "IMKREG02", "services"),
        ("IMKINST01", "InputMethodInstaller.swift", "IMKINST02", "services"),
        ("IMKNOTIF01", "Notifications.swift", "IMKNOTIF02", "models"),
    ]
    imk_files = [
        ("IMKMAIN01", "main.swift", "IMKMAIN02"),
        ("IMKCTRL01", "ChorderInputController.swift", "IMKCTRL02"),
        ("IMKINS01", "IMKTextInserter.swift", "IMKINS02"),
        ("IMKSESS01", "IMKChordSession.swift", "IMKSESS02"),
        ("IMKSHREG01", "SharedSettingsChordRegistry.swift", "IMKSHREG02"),
    ]

    build_lines, ref_lines = [], []
    chorder_src, services_refs, models_refs = [], [], []
    imk_group, imk_src = [], []

    for ref, name, bld, group in app_files:
        quoted = f'"{name}"' if "+" in name else name
        ref_lines.append(
            f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted}; sourceTree = "<group>"; }};'
        )
        build_lines.append(
            f'\t\t{bld} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};'
        )
        chorder_src.append(f"\t\t\t\t{bld} /* {name} in Sources */,")
        (services_refs if group == "services" else models_refs).append(
            f"\t\t\t\t{ref} /* {name} */,"
        )

    for ref, name, bld in imk_files:
        ref_lines.append(
            f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};'
        )
        build_lines.append(
            f'\t\t{bld} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};'
        )
        imk_group.append(f"\t\t\t\t{ref} /* {name} */,")
        imk_src.append(f"\t\t\t\t{bld} /* {name} in Sources */,")

    build_lines += [
        f"\t\t{FW_CHORDER} /* ChorderCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {PKG_CHORDER} /* ChorderCore */; }};",
        f"\t\t{FW_TESTS} /* ChorderCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {PKG_TESTS} /* ChorderCore */; }};",
        f"\t\t{FW_IMK} /* ChorderCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {PKG_IMK} /* ChorderCore */; }};",
        f"\t\t{FW_IMK_KIT} /* InputMethodKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {FW_IMK_KIT_REF} /* InputMethodKit.framework */; }};",
        f"\t\t{COPY_FILE} /* ChorderInputMethod.bundle in Copy Files */ = {{isa = PBXBuildFile; fileRef = {IMK_PRODUCT} /* ChorderInputMethod.bundle */; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy); }}; }};",
    ]
    ref_lines += [
        f"\t\t{FW_IMK_KIT_REF} /* InputMethodKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = InputMethodKit.framework; path = System/Library/Frameworks/InputMethodKit.framework; sourceTree = SDKROOT; }};",
        '\t\tIMKPLIST01 /* ChorderInputMethod-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "ChorderInputMethod-Info.plist"; sourceTree = "<group>"; };',
        "\t\tIMKENT01 /* ChorderInputMethod.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = ChorderInputMethod.entitlements; sourceTree = \"<group>\"; };",
        f"\t\t{IMK_PRODUCT} /* ChorderInputMethod.bundle */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ChorderInputMethod.bundle; sourceTree = BUILT_PRODUCTS_DIR; }};",
    ]

    for old in [
        "08E19F2129DE1A950081AB4E /* Chord.swift in Sources */",
        "E5F697A82DA6B2D200B360A5 /* ChordDetectionState.swift in Sources */",
        "A1B2C3D42DA6B2D200B360A1 /* OutputPlaceholderExpansion.swift in Sources */",
    ]:
        c = c.replace(f"\t\t\t\t{old},\n", "")

    c = c.replace("/* End PBXBuildFile section */", "\n".join(build_lines) + "\n/* End PBXBuildFile section */")
    c = c.replace("/* End PBXFileReference section */", "\n".join(ref_lines) + "\n/* End PBXFileReference section */")

    c = c.replace(
        "\t\t\tfiles = (\n\t\t\t\t0898B41B2BE16DBA0087D747 /* LaunchAtLogin in Frameworks */,",
        f"\t\t\tfiles = (\n\t\t\t\t{FW_CHORDER} /* ChorderCore in Frameworks */,\n\t\t\t\t0898B41B2BE16DBA0087D747 /* LaunchAtLogin in Frameworks */,",
    )
    c = c.replace(
        "08E19EFC29DE19F90081AB4E /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);",
        f"08E19EFC29DE19F90081AB4E /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t{FW_TESTS} /* ChorderCore in Frameworks */,\n\t\t\t);",
    )

    c = c.replace(
        "08E19EE529DE19F80081AB4E = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t08E19EF029DE19F80081AB4E /* Chorder */,",
        "08E19EE529DE19F80081AB4E = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\tIMKGRP01 /* ChorderInputMethod */,\n\t\t\t\tPKGGRP01 /* ChorderCore */,\n\t\t\t\t08E19EF029DE19F80081AB4E /* Chorder */,",
    )
    c = c.replace(
        "08E19EEE29DE19F80081AB4E /* Chorder.app */,",
        f"08E19EEE29DE19F80081AB4E /* Chorder.app */,\n\t\t\t\t{IMK_PRODUCT} /* ChorderInputMethod.bundle */,",
    )
    c = c.replace(
        "PRCA00062DA6B2D200B360B1 /* PracticeChordMonitor.swift */,",
        "PRCA00062DA6B2D200B360B1 /* PracticeChordMonitor.swift */,\n" + "\n".join(services_refs),
    )
    c = c.replace("08E19F2029DE1A950081AB4E /* Chord.swift */,", "\n".join(models_refs))
    for old in [
        "\t\t\t\t08E19F2029DE1A950081AB4E /* Chord.swift */,\n",
        "\t\t\t\tE5F697A72DA6B2D200B360A5 /* ChordDetectionState.swift */,\n",
        "\t\t\t\tA1B2C3D32DA6B2D200B360A1 /* OutputPlaceholderExpansion.swift */,\n",
    ]:
        c = c.replace(old, "")

    c = c.replace(
        "/* End PBXGroup section */",
        f"""\t\tPKGGRP01 /* ChorderCore */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t);
\t\t\tname = ChorderCore;
\t\t\tpath = ChorderCore;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\tIMKGRP01 /* ChorderInputMethod */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(imk_group)}
\t\t\t\tIMKPLIST01 /* ChorderInputMethod-Info.plist */,
\t\t\t\tIMKENT01 /* ChorderInputMethod.entitlements */,
\t\t\t);
\t\t\tpath = ChorderInputMethod;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */""",
    )

    c = c.replace(
        "STCA00032DA6B2D200B360B1 /* StatsView.swift in Sources */,",
        "STCA00032DA6B2D200B360B1 /* StatsView.swift in Sources */,\n" + "\n".join(chorder_src),
    )

    c = c.replace(
        "08E19EED29DE19F80081AB4E /* Chorder */ = {\n\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = 08E19F1329DE19F90081AB4E /* Build configuration list for PBXNativeTarget \"Chorder\" */;\n\t\t\tbuildPhases = (\n\t\t\t\t08E19EEA29DE19F80081AB4E /* Sources */,\n\t\t\t\t08E19EEB29DE19F80081AB4E /* Frameworks */,\n\t\t\t\t08E19EEC29DE19F80081AB4E /* Resources */,",
        f"08E19EED29DE19F80081AB4E /* Chorder */ = {{\n\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = 08E19F1329DE19F90081AB4E /* Build configuration list for PBXNativeTarget \"Chorder\" */;\n\t\t\tbuildPhases = (\n\t\t\t\t08E19EEA29DE19F80081AB4E /* Sources */,\n\t\t\t\t08E19EEB29DE19F80081AB4E /* Frameworks */,\n\t\t\t\t08E19EEC29DE19F80081AB4E /* Resources */,\n\t\t\t\t{COPY_PHASE} /* Copy Files */,",
    )
    c = c.replace(
        'dependencies = (\n\t\t\t);\n\t\t\tname = "Chorder";',
        f"dependencies = (\n\t\t\t\t{IMK_DEP} /* PBXTargetDependency */,\n\t\t\t);\n\t\t\tname = \"Chorder\";",
    )
    c = c.replace(
        "packageProductDependencies = (\n\t\t\t\t0898B41A2BE16DBA0087D747 /* LaunchAtLogin */,",
        f"packageProductDependencies = (\n\t\t\t\t{PKG_CHORDER} /* ChorderCore */,\n\t\t\t\t0898B41A2BE16DBA0087D747 /* LaunchAtLogin */,",
    )
    c = c.replace(
        'name = "ChorderTests";\n\t\t\tproductName = "ChorderTests";',
        f'name = "ChorderTests";\n\t\t\tpackageProductDependencies = (\n\t\t\t\t{PKG_TESTS} /* ChorderCore */,\n\t\t\t);\n\t\t\tproductName = "ChorderTests";',
    )

    imk_settings = """
\t\t\t\tCODE_SIGN_ENTITLEMENTS = ChorderInputMethod/ChorderInputMethod.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = F2NH4J9NYG;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = ChorderInputMethod/ChorderInputMethod-Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t\t"@executable_path/../../../../Frameworks",
\t\t\t\t);
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.3;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = uk.co.georgegillams.inputmethod.chorder;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tWRAPPER_EXTENSION = bundle;
"""

    c = c.replace(
        "/* End PBXNativeTarget section */",
        f"""\t\t{IMK_TARGET} /* ChorderInputMethod */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {IMK_CFG_LIST} /* Build configuration list for PBXNativeTarget "ChorderInputMethod" */;
\t\t\tbuildPhases = (
\t\t\t\t{IMK_SOURCES} /* Sources */,
\t\t\t\t{IMK_FRAMEWORKS} /* Frameworks */,
\t\t\t\t{IMK_RESOURCES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = ChorderInputMethod;
\t\t\tpackageProductDependencies = (
\t\t\t\t{PKG_IMK} /* ChorderCore */,
\t\t\t);
\t\t\tproductName = ChorderInputMethod;
\t\t\tproductReference = {IMK_PRODUCT} /* ChorderInputMethod.bundle */;
\t\t\tproductType = "com.apple.product-type.bundle";
\t\t}};
/* End PBXNativeTarget section */""",
    )

    # Ensure local package ref exists in project packageReferences
    if "XCLocalSwiftPackageReference" not in c:
        c = c.replace(
            "packageReferences = (\n\t\t\t\t0898B4192BE16D140087D747 /* XCRemoteSwiftPackageReference \"LaunchAtLogin-Modern\" */,",
            f"packageReferences = (\n\t\t\t\t{PKG_REF} /* XCLocalSwiftPackageReference \"ChorderCore\" */,\n\t\t\t\t0898B4192BE16D140087D747 /* XCRemoteSwiftPackageReference \"LaunchAtLogin-Modern\" */,",
        )
        c = c.replace(
            "/* End XCRemoteSwiftPackageReference section */",
            f"""/* End XCRemoteSwiftPackageReference section */

/* Begin XCLocalSwiftPackageReference section */
\t\t{PKG_REF} /* XCLocalSwiftPackageReference "ChorderCore" */ = {{
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = ChorderCore;
\t\t}};
/* End XCLocalSwiftPackageReference section */""",
        )
    else:
        # reuse existing local ref id from file
        import re

        m = re.search(r"(\w+) /\* XCLocalSwiftPackageReference \"ChorderCore\" \*/", c)
        if m:
            PKG_REF = m.group(1)

    c = c.replace(
        "targets = (\n\t\t\t\t08E19EED29DE19F80081AB4E /* Chorder */,",
        f"targets = (\n\t\t\t\t08E19EED29DE19F80081AB4E /* Chorder */,\n\t\t\t\t{IMK_TARGET} /* ChorderInputMethod */,",
    )

    c = c.replace(
        "/* End PBXContainerItemProxy section */",
        f"""\t\t{IMK_PROXY} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 08E19EE629DE19F80081AB4E /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {IMK_TARGET};
\t\t\tremoteInfo = ChorderInputMethod;
\t\t}};
/* End PBXContainerItemProxy section */""",
    )

    c = c.replace(
        "/* End PBXResourcesBuildPhase section */",
        f"""\t\t{COPY_PHASE} /* Copy Files */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "Contents/Library/Input Methods";
\t\t\tdstSubfolderSpec = 1;
\t\t\tfiles = (
\t\t\t\t{COPY_FILE} /* ChorderInputMethod.bundle in Copy Files */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{IMK_SOURCES} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(imk_src)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{IMK_FRAMEWORKS} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{FW_IMK} /* ChorderCore in Frameworks */,
\t\t\t\t{FW_IMK_KIT} /* InputMethodKit.framework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{IMK_RESOURCES} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */""",
    )

    c = c.replace(
        "/* End PBXTargetDependency section */",
        f"""\t\t{IMK_DEP} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {IMK_TARGET} /* ChorderInputMethod */;
\t\t\ttargetProxy = {IMK_PROXY} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */""",
    )

    c = c.replace(
        "/* End XCBuildConfiguration section */",
        f"""\t\t{IMK_DBG} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{imk_settings}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{IMK_REL} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{imk_settings}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */""",
    )

    c = c.replace(
        "/* End XCConfigurationList section */",
        f"""\t\t{IMK_CFG_LIST} /* Build configuration list for PBXNativeTarget "ChorderInputMethod" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{IMK_DBG} /* Debug */,
\t\t\t\t{IMK_REL} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */""",
    )

    if f"package = {PKG_REF}" not in c:
        c = c.replace(
            "/* End XCSwiftPackageProductDependency section */",
            f"""\t\t{PKG_CHORDER} /* ChorderCore */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {PKG_REF} /* XCLocalSwiftPackageReference "ChorderCore" */;
\t\t\tproductName = ChorderCore;
\t\t}};
\t\t{PKG_TESTS} /* ChorderCore */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {PKG_REF} /* XCLocalSwiftPackageReference "ChorderCore" */;
\t\t\tproductName = ChorderCore;
\t\t}};
\t\t{PKG_IMK} /* ChorderCore */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {PKG_REF} /* XCLocalSwiftPackageReference "ChorderCore" */;
\t\t\tproductName = ChorderCore;
\t\t}};
/* End XCSwiftPackageProductDependency section */""",
        )

    PBX.write_text(c)
    print(f"Patched {PBX}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3

# Read the project file
with open('/home/kaikedev/main/ThreeOneOSFive.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Backup
with open('/home/kaikedev/main/ThreeOneOSFive.xcodeproj/project.pbxproj.bak', 'w') as f:
    f.write(content)

# Add PBXBuildFile entries (after 3105N201)
content = content.replace(
    '\t\t3105N201 /* ReplayTransferView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 3105N101; };',
    '\t\t3105N201 /* ReplayTransferView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 3105N101; };\n\t\t3105N202 /* ReplayConnectionView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 3105N102; };\n\t\t3105N203 /* ReplayConnectionManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = 3105N103; };'
)

# Add PBXFileReference entries (after 3105N101)
content = content.replace(
    '\t\t3105N101 /* ReplayTransferView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReplayTransferView.swift; sourceTree = "<group>"; };',
    '\t\t3105N101 /* ReplayTransferView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReplayTransferView.swift; sourceTree = "<group>"; };\n\t\t3105N102 /* ReplayConnectionView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReplayConnectionView.swift; sourceTree = "<group>"; };\n\t\t3105N103 /* ReplayConnectionManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReplayConnectionManager.swift; sourceTree = "<group>"; };'
)

# Add file references in ThreeOneOSFive group (root)
content = content.replace(
    '\t\t\t\t3105N101 /* ReplayTransferView.swift */,',
    '\t\t\t\t3105N101 /* ReplayTransferView.swift */,\n\t\t\t\t3105N102 /* ReplayConnectionView.swift */,'
)

# Add file references in helpers group  
content = content.replace(
    '\t\t\t\t3105N100 /* ReplayHTTPServer.swift */,',
    '\t\t\t\t3105N100 /* ReplayHTTPServer.swift */,\n\t\t\t\t3105N103 /* ReplayConnectionManager.swift */,'
)

# Add in PBXSourcesBuildPhase
content = content.replace(
    '\t\t\t\t3105N200 /* ReplayHTTPServer.swift in Sources */,',
    '\t\t\t\t3105N200 /* ReplayHTTPServer.swift in Sources */,\n\t\t\t\t3105N202 /* ReplayConnectionView.swift in Sources */,\n\t\t\t\t3105N203 /* ReplayConnectionManager.swift in Sources */,'
)

# Write back
with open('/home/kaikedev/main/ThreeOneOSFive.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print('✅ Files added to Xcode project successfully!')

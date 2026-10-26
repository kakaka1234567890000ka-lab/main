#!/usr/bin/env python3

with open("ThreeOneOSFive.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# Adicionar 3105N202 e 3105N203 na seção PBXSourcesBuildPhase
content = content.replace(
    "3105N201,\n\t\t\t);",
    "3105N201,\n\t\t\t3105N202,\n\t\t\t3105N203,\n\t\t\t);"
)

with open("ThreeOneOSFive.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)

print("✅ Adicionado 3105N202 e 3105N203 na seção PBXSourcesBuildPhase!")

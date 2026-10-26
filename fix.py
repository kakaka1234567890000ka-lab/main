#!/usr/bin/env python3

with open("ThreeOneOSFive.xcodeproj/project.pbxproj", "r") as f:
    lines = f.readlines()

# Encontrar a linha com 3105N201 e adicionar as próximas linhas
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if "3105N201," in line and i < len(lines) - 1 and ");" in lines[i+1]:
        # Adicionar as duas novas linhas ANTES do ");
        indent = line[:len(line) - len(line.lstrip())]  # Pegar a indentação
        new_lines.append(f"{indent}3105N202,\n")
        new_lines.append(f"{indent}3105N203,\n")

with open("ThreeOneOSFive.xcodeproj/project.pbxproj", "w") as f:
    f.writelines(new_lines)

print("✅ Adicionado 3105N202 e 3105N203!")

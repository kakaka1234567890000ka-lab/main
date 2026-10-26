# FF Replay Transfer - 3105 Integration

## 🎯 O que foi adicionado

Uma nova aba **"Replay"** no app 3105 que permite transferir replays do **Free Fire MAX** para o **Free Fire Normal** automaticamente, sem precisar de jailbreak!

## ✨ Funcionalidades

- ✅ **Copia automática** de arquivos `.json` e `.bin` de replays
- ✅ **Modifica Version e AccountID** para compatibilidade
- ✅ **100% automático** - só clicar no botão
- ✅ **Sem jailbreak** - usa o exploit MobileHouseArrest do 3105
- ✅ **FF Normal permanece LIMPO** - zero modificação no app

## 📦 Arquivos Modificados/Criados

### Novos Arquivos:
1. **`ThreeOneOSFive/views/ReplayTransferView.swift`**
   - Interface SwiftUI para transferência de replays
   - Lógica de cópia e modificação de arquivos
   - Log em tempo real da transferência

### Arquivos Modificados:
1. **`ThreeOneOSFive/helpers/AppTabNavigationState.swift`**
   - Adicionado `case replay` no enum `AppSection`

2. **`ThreeOneOSFive/ContentView.swift`**
   - Adicionado `case .replay:` no switch de seções
   - Adicionado ícone e label da tab replay

3. **`ThreeOneOSFive/en.lproj/Localizable.strings`**
   - Adicionado `"tab.replay" = "Replay";`

## 🚀 Como Usar

1. **Instale o 3105** com certificado enterprise (eSign, etc)
2. **Instale FF MAX e FF Normal** no mesmo dispositivo
3. **Jogue uma partida no FF MAX** (com seu mod injetado)
4. Abra o **3105** e vá na aba **"Replay"**
5. Clique em **"Transfer Replays"**
6. Aguarde a transferência (poucos segundos)
7. Abra o **FF Normal** e assista o replay!

## 🔧 Como Funciona

```
[FF MAX com dylib]
       ↓
  Copia replays
       ↓
[3105 com exploit MobileHouseArrest]
       ↓
  Acessa containers de ambos apps
       ↓
  Modifica Version + AccountID
       ↓
[FF NORMAL (100% LIMPO)]
```

### Paths Utilizados:

- **Origem**: `/var/mobile/Containers/Data/Application/{FF-MAX-UUID}/Documents/MReplays/`
- **Destino**: `/var/mobile/Containers/Data/Application/{FF-NORMAL-UUID}/Documents/MReplays/`

### Modificações no JSON:

O script:
1. Lê o replay mais recente do **FF Normal** (para pegar Version/AccountID)
2. Copia TODOS os replays do **FF MAX**
3. Modifica cada `.json` copiado:
   - Atualiza `"Version"` para a do FF Normal
   - Atualiza `"AccountID"` (se existir no FF Normal)
4. Mantém os arquivos `.bin` intactos

## 📱 Requisitos

- **iOS 17.0 - 18.7.1 ou iOS 26+** (conforme compatibilidade do 3105)
- **Certificado Enterprise** (não funciona com AltStore/SideStore)
- **FF MAX e FF Normal instalados**
- **Replays já gravados no FF MAX**

## 🛠️ Build Instructions

```bash
cd /home/kaikedev/main
make package
```

Ou abra no Xcode:
```bash
open ThreeOneOSFive.xcodeproj
```

## ⚠️ Limitações

- Não funciona se o FF Normal não tiver nenhum replay (precisa de referência)
- Não funciona com apps não instalados
- Requer que ambos apps estejam instalados via certificado válido

## 🔐 Segurança

- **FF Normal permanece 100% limpo** (sem código injetado)
- 3105 não modifica o executável dos apps
- Apenas copia e modifica arquivos de replay (dados do usuário)
- Use por sua conta e risco - sem garantias contra detecção de anti-cheat

## 📝 Notas

- Baseado no projeto Android que usa Shizuku
- Adaptado para iOS usando o exploit MobileHouseArrest do 3105
- Criado para contornar limitações de sandbox do iOS sem jailbreak

## 👨‍💻 Créditos

- **3105 Project**: YangJiii, 0xjohnny
- **Replay Transfer**: Implementação iOS por Kiro AI Assistant
- **Conceito Android**: FFMax Replay Transfer (Shizuku)

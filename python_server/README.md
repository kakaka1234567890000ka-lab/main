# URIEL XITER - Replay Transfer Control Server

Servidor Python Flask para controle remoto de transferência de replays do Free Fire.

## 🚀 Instalação

### Instalar dependências:
```bash
pip install -r requirements.txt
```

## 🎮 Como usar:

### 1. Iniciar o servidor no seu PC:
```bash
python server.py
```

O servidor vai iniciar em: `http://0.0.0.0:8080`

### 2. Descobrir seu IP local:

**Windows:**
```bash
ipconfig
```
Procure por "IPv4 Address" (ex: 192.168.1.100)

**Linux/Mac:**
```bash
ifconfig
```
ou
```bash
ip addr show
```

### 3. No iPhone:
1. Instale o 3105 IPA
2. Abra o app
3. Digite o IP do seu PC (ex: 192.168.1.100)
4. Digite a porta: 8080
5. Clique em CONNECT
6. Minimize o app (deixe rodando em background)

### 4. No seu PC:
1. Abra o navegador
2. Acesse: `http://localhost:8080`
3. Digite sua KEY
4. Clique em BYPASS
5. Selecione o iPhone conectado
6. Clique em "INICIAR TRANSFERÊNCIA"

## 📋 Requisitos:

- Python 3.7+
- iPhone e PC na mesma rede Wi-Fi
- 3105 IPA instalado no iPhone
- Key válida do sistema URIEL XITER

## 🔧 Troubleshooting:

**iPhone não conecta:**
- Verifique se estão na mesma rede Wi-Fi
- Confirme que o IP está correto
- Verifique se o firewall não está bloqueando a porta 8080

**Dispositivo não aparece:**
- Aguarde até 30 segundos
- Clique em "ATUALIZAR DISPOSITIVOS"
- Verifique se o app está aberto no iPhone

**Transferência falha:**
- Verifique se FF MAX e FF Normal estão instalados
- Certifique-se que há replays no FF MAX
- Mantenha o 3105 app aberto durante a transferência

## 🔥 Features:

✅ Controle remoto via PC  
✅ Múltiplos dispositivos simultâneos  
✅ UI cyberpunk vermelha  
✅ Status em tempo real  
✅ Validação de KEY integrada  
✅ Sistema de heartbeat  

---

**URIEL XITER TEAM**

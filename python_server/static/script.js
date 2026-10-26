let selectedDeviceId = null;
let devicesRefreshInterval = null;

async function login() {
    const key = document.getElementById('key').value.trim();
    const btn = document.getElementById('loginBtn');
    const msgDiv = document.getElementById('loginMessage');
    
    if (!key) {
        showMessage(msgDiv, 'KEY OBRIGATÓRIA', 'error');
        return;
    }
    
    btn.disabled = true;
    btn.innerHTML = '<span class="loading"></span>VALIDANDO...';
    
    try {
        const formData = new FormData();
        formData.append('key', key);
        
        const response = await fetch('/api/login', {
            method: 'POST',
            body: formData
        });
        
        const data = await response.json();
        
        if (data.success) {
            document.getElementById('loginContainer').classList.add('hidden');
            document.getElementById('dashboard').classList.remove('hidden');
            
            // Start refreshing devices
            refreshDevices();
            devicesRefreshInterval = setInterval(refreshDevices, 5000); // Refresh every 5 seconds
        } else {
            showMessage(msgDiv, 'ACESSO NEGADO: ' + (data.message || 'KEY INVÁLIDA'), 'error');
            btn.disabled = false;
            btn.innerHTML = 'BYPASS';
        }
    } catch (error) {
        console.error('Login error:', error);
        showMessage(msgDiv, 'ERRO DE CONEXÃO', 'error');
        btn.disabled = false;
        btn.innerHTML = 'BYPASS';
    }
}

async function refreshDevices() {
    try {
        const response = await fetch('/api/devices');
        const data = await response.json();
        
        const devicesList = document.getElementById('devicesList');
        
        if (!data.devices || data.devices.length === 0) {
            devicesList.innerHTML = '<div class="no-devices">Nenhum dispositivo conectado</div>';
            return;
        }
        
        devicesList.innerHTML = '';
        
        data.devices.forEach(device => {
            const deviceItem = document.createElement('div');
            deviceItem.className = 'device-item';
            if (device.device_id === selectedDeviceId) {
                deviceItem.classList.add('selected');
            }
            
            deviceItem.onclick = () => selectDevice(device);
            
            const isOnline = device.status === 'online';
            
            deviceItem.innerHTML = `
                <div class="device-info">
                    <div class="device-name">${device.device_name}</div>
                    <div class="device-details">
                        ${device.device_ip}:${device.local_port} • iOS ${device.ios_version}
                    </div>
                </div>
                <div class="device-status ${isOnline ? 'status-online' : 'status-offline'}">
                    <div class="status-dot"></div>
                    ${isOnline ? 'ONLINE' : 'OFFLINE'}
                </div>
            `;
            
            devicesList.appendChild(deviceItem);
        });
    } catch (error) {
        console.error('Error refreshing devices:', error);
    }
}

function selectDevice(device) {
    selectedDeviceId = device.device_id;
    
    // Update selected device display
    const selectedDeviceDiv = document.getElementById('selectedDevice');
    selectedDeviceDiv.innerHTML = `
        <div style="color: #fff; font-weight: 600; margin-bottom: 5px;">
            ${device.device_name}
        </div>
        <div style="color: #888; font-size: 12px;">
            ${device.device_ip}:${device.local_port} • iOS ${device.ios_version}
        </div>
    `;
    
    // Enable transfer button
    document.getElementById('transferBtn').disabled = false;
    
    // Update device list to show selection
    refreshDevices();
}

async function transferReplays() {
    if (!selectedDeviceId) {
        return;
    }
    
    const btn = document.getElementById('transferBtn');
    const msgDiv = document.getElementById('transferMessage');
    
    btn.disabled = true;
    btn.innerHTML = '<span class="loading"></span>TRANSFERINDO...';
    
    try {
        const response = await fetch(`/api/transfer/${selectedDeviceId}`, {
            method: 'POST'
        });
        
        const data = await response.json();
        
        if (data.success) {
            showMessage(msgDiv, 'TRANSFERÊNCIA CONCLUÍDA: ' + data.message, 'success');
        } else {
            showMessage(msgDiv, 'FALHA: ' + data.message, 'error');
        }
    } catch (error) {
        console.error('Transfer error:', error);
        showMessage(msgDiv, 'ERRO NA TRANSFERÊNCIA', 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = 'INICIAR TRANSFERÊNCIA';
    }
}

function showMessage(div, text, type) {
    div.className = `message ${type}`;
    div.textContent = text;
    div.style.display = 'block';
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        div.style.display = 'none';
    }, 5000);
}

function logout() {
    if (devicesRefreshInterval) {
        clearInterval(devicesRefreshInterval);
    }
    
    selectedDeviceId = null;
    document.getElementById('dashboard').classList.add('hidden');
    document.getElementById('loginContainer').classList.remove('hidden');
    document.getElementById('key').value = '';
}

// Focus on key input
document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('key').focus();
    
    // Enter key to login
    document.getElementById('key').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            login();
        }
    });
});

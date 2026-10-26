from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
from datetime import datetime
import requests
import logging

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Store connected devices
connected_devices = {}

class Device:
    def __init__(self, device_id, device_name, device_ip, local_port, ios_version):
        self.device_id = device_id
        self.device_name = device_name
        self.device_ip = device_ip
        self.local_port = local_port
        self.ios_version = ios_version
        self.last_heartbeat = datetime.now()
        self.status = "online"
    
    def update_heartbeat(self):
        self.last_heartbeat = datetime.now()
        self.status = "online"
    
    def to_dict(self):
        return {
            "device_id": self.device_id,
            "device_name": self.device_name,
            "device_ip": self.device_ip,
            "local_port": self.local_port,
            "ios_version": self.ios_version,
            "last_heartbeat": self.last_heartbeat.isoformat(),
            "status": self.status
        }

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/device/register', methods=['POST'])
def register_device():
    """Register a new iOS device"""
    try:
        data = request.json
        device_id = data.get('device_id')
        device_name = data.get('device_name')
        local_port = data.get('local_port')
        ios_version = data.get('ios_version')
        
        # Get device IP from request
        device_ip = request.remote_addr
        
        logger.info(f"Device registration: {device_name} ({device_id}) from {device_ip}:{local_port}")
        
        # Create or update device
        device = Device(device_id, device_name, device_ip, local_port, ios_version)
        connected_devices[device_id] = device
        
        logger.info(f"Device registered successfully: {device_name}")
        
        return jsonify({
            "success": True,
            "message": "Device registered successfully",
            "device_id": device_id
        }), 200
        
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/device/heartbeat', methods=['POST'])
def device_heartbeat():
    """Update device heartbeat"""
    try:
        data = request.json
        device_id = data.get('device_id')
        
        if device_id in connected_devices:
            connected_devices[device_id].update_heartbeat()
            return jsonify({"success": True}), 200
        else:
            return jsonify({"success": False, "error": "Device not found"}), 404
            
    except Exception as e:
        logger.error(f"Heartbeat error: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/devices', methods=['GET'])
def get_devices():
    """Get list of connected devices"""
    devices_list = [device.to_dict() for device in connected_devices.values()]
    return jsonify({"devices": devices_list})

@app.route('/api/transfer/<device_id>', methods=['POST'])
def transfer_replays(device_id):
    """Send transfer command to specific device"""
    try:
        if device_id not in connected_devices:
            return jsonify({
                "success": False,
                "message": "Device not found or offline"
            }), 404
        
        device = connected_devices[device_id]
        device_url = f"http://{device.device_ip}:{device.local_port}/transfer"
        
        logger.info(f"Sending transfer command to {device.device_name} at {device_url}")
        
        # Send transfer command to device
        response = requests.post(device_url, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            logger.info(f"Transfer result: {result}")
            return jsonify(result), 200
        else:
            logger.error(f"Transfer failed: {response.status_code}")
            return jsonify({
                "success": False,
                "message": f"Device returned error: {response.status_code}"
            }), 500
            
    except requests.exceptions.Timeout:
        logger.error("Transfer timeout")
        return jsonify({
            "success": False,
            "message": "Transfer timeout - device not responding"
        }), 504
    except requests.exceptions.ConnectionError:
        logger.error("Connection error")
        return jsonify({
            "success": False,
            "message": "Cannot connect to device"
        }), 503
    except Exception as e:
        logger.error(f"Transfer error: {str(e)}")
        return jsonify({
            "success": False,
            "message": f"Error: {str(e)}"
        }), 500

@app.route('/api/login', methods=['POST'])
def login():
    """Validate login key"""
    try:
        key = request.form.get('key')
        
        if not key:
            return jsonify({
                "success": False,
                "message": "Key is required"
            }), 400
        
        # Validate key with urielxiter.shop
        import urllib.parse
        device_uid = "SERVER-" + request.remote_addr.replace('.', '-')
        
        validation_url = f"https://urielxiter.shop/mod/CheckLogin.php?user={urllib.parse.quote(key)}&uid={urllib.parse.quote(device_uid)}"
        
        logger.info(f"Validating key: {key}")
        
        response = requests.get(validation_url, timeout=15)
        response_text = response.text.strip()
        
        # Check for error prefixes
        error_prefixes = [
            "Em manutenção",
            "Usuário inválido",
            "Dispositivo não permitido",
            "Usuário banido",
            "Usuário pausado",
            "Key expirada",
            "Configuração de dispositivo inválida"
        ]
        
        is_error = any(response_text.lower().startswith(prefix.lower()) for prefix in error_prefixes) or not response_text
        
        if is_error:
            logger.info(f"Key validation failed: {response_text}")
            return jsonify({
                "success": False,
                "message": "Key inválida ou expirada"
            }), 401
        else:
            logger.info(f"Key validated successfully")
            return jsonify({
                "success": True,
                "message": "Login successful"
            }), 200
            
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({
            "success": False,
            "message": "Erro ao validar key"
        }), 500

if __name__ == '__main__':
    logger.info("=" * 60)
    logger.info("URIEL XITER - REPLAY TRANSFER SERVER")
    logger.info("=" * 60)
    logger.info("Server starting on http://0.0.0.0:8080")
    logger.info("Access from your PC: http://localhost:8080")
    logger.info("Access from network: http://<YOUR_IP>:8080")
    logger.info("=" * 60)
    
    app.run(host='0.0.0.0', port=8080, debug=True)

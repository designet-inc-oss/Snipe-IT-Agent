import requests
import json
import socket
import psutil
import platform
import snipe_config
import argparse
import subprocess
import os
import sys
import warnings

parser = argparse.ArgumentParser(description='Snipe-IT asset updater')
parser.add_argument('--model-id', type=int, required=True, help='Model ID')
parser.add_argument('--fieldset-id', type=int, required=True, help='Fieldset ID')
parser.add_argument('--asset-name', type=str, help='Asset name (if different from hostname)')
parser.add_argument('--debug', action='store_true', help='Enable debug output')
args = parser.parse_args()

if not args.debug:
    warnings.filterwarnings('ignore', message='Unverified HTTPS request')

# get computer name (hostname)
# value specified by --asset-name option
hostname = socket.gethostname()
asset_name = args.asset_name if args.asset_name else hostname

# get ip address
def get_non_loopback_ip():
    for iface, addrs in psutil.net_if_addrs().items():
        for addr in addrs:
            if addr.family == socket.AF_INET and not addr.address.startswith('127.'):
                return addr.address
    return '127.0.0.1'

ip_address = get_non_loopback_ip()

#  get number of CPU threads
cpu_count = psutil.cpu_count()

# get memory size (GB)
mem = psutil.virtual_memory().total / (1024 ** 3)

# get disk size (GB)
total_disk = sum(psutil.disk_usage(part.mountpoint).total for part in psutil.disk_partitions() if os.access(part.mountpoint, os.R_OK)) / (1024 ** 3)

# get disk info
disk_info = ''
for part in psutil.disk_partitions():
    try:
        usage = psutil.disk_usage(part.mountpoint)
        disk_info += f"{part.device} {part.fstype} {part.mountpoint} {usage.total / (1024 ** 3):.2f} GB\n"
    except PermissionError:
        continue

# data formatting (installed apps / device info / network info) 
def clean_output(output):
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    if lines[0] == 'Name':
        retlines = lines[1:]
    else:
        retlines = lines
    return '\n'.join(retlines)

# get installed apps
installed_apps = ''
try:
    if platform.system() == 'Windows':
        command = [
            'powershell',
            '-Command',
            r"Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object -ExpandProperty DisplayName"
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        installed_apps = clean_output(result.stdout)
    elif platform.system() == 'Linux':
        if os.path.exists('/etc/redhat-release'):
            result = subprocess.run(['rpm', '-qa'], capture_output=True, text=True)
        else:
            result = subprocess.run(['dpkg-query', '-f', '${binary:Package}\n', '-W'], capture_output=True, text=True)
        installed_apps = clean_output(result.stdout)
except Exception as e:
    installed_apps = f"Error collecting apps: {e}"

# get computer info
cpu_model_info = ''
if platform.system() == 'Linux':
    try:
        with open('/proc/cpuinfo') as f:
            for line in f:
                if 'model name' in line:
                    cpu_model_info = line.strip().split(': ')[1]
                    break
    except Exception:
        cpu_model_info = platform.processor()
else:
    cpu_model_info = platform.processor()

computer_info = f"CPU: {cpu_model_info}, {cpu_count} cores"

# get device info
device_info = ''
try:
    if platform.system() == 'Windows':
        command = [
            'powershell',
            '-Command',
            'Get-PnpDevice | Select-Object -ExpandProperty FriendlyName'
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        device_info = clean_output(result.stdout)
    elif platform.system() == 'Linux':
        result = subprocess.run(['lspci'], capture_output=True, text=True)
        device_info = clean_output(result.stdout)
except Exception as e:
    device_info = f"Error collecting device info: {e}"

# get network info
network_info = ''
for iface, addrs in psutil.net_if_addrs().items():
    for addr in addrs:
        if addr.family == socket.AF_INET:
            network_info += f"{iface}: {addr.address}\n"
network_info = clean_output(network_info)

# get linux os-release
def get_os_release():
    osrelease = {}
    path = '/etc/os-release'
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line and '=' in line:
                    key, value = line.split('=', 1)
                    # remove quotes at both ends of value
                    osrelease[key] = value.strip('"')
        pretty = osrelease['PRETTY_NAME']
    except Exception as e:
        pretty = f"Error collecting os info: {e}"
    return pretty

# get os info
if platform.system() == 'Linux':
    try:
        os_info = get_os_release()
    except Exception:
        os_info = f"Linux {platform.release()}"
else:
    os_info = f"{platform.system()} {platform.release()}"

# search exist assets data
url = f"{snipe_config.SNIPE_URL}/hardware?search={asset_name}"
headers = {
    'Authorization': f'Bearer {snipe_config.API_TOKEN}',
    'Accept': 'application/json'
}

try:
    response = requests.get(url, headers=headers, verify=False)
    data = response.json()
except Exception as e:
    print(f"Failed to connect to Snipe-IT: {e}")
    sys.exit()

# determine whether to create or update
asset_id = None
if data.get('total', 0) > 0:
    for row in data['rows']:
        if row['name'] == asset_name:
            asset_id = row['id']
            break

# target item
payload = {
    'name': asset_name,
    'model_id': args.model_id,
    'fieldset_id': args.fieldset_id,
    snipe_config.IPField: ip_address,
    snipe_config.HostnameField: hostname,
    snipe_config.CPUField: str(cpu_count),
    snipe_config.MemoryField: f"{mem:.2f}",
    snipe_config.DiskField: f"{total_disk:.2f}",
    snipe_config.DiskInfoField: disk_info.strip(),
    snipe_config.AppsField: installed_apps,
    snipe_config.ComputerInfoField: computer_info,
    snipe_config.DeviceInfoField: device_info,
    snipe_config.NetworkInfoField: network_info,
    snipe_config.OSinfoField: os_info
}

# create or update
if asset_id:
    print(f"✅ 既存資産を更新します (ID: {asset_id})")
    target_url = f"{snipe_config.SNIPE_URL}/hardware/{asset_id}"
    method = requests.patch
else:
    print("✅ 新規資産を作成します")
    target_url = f"{snipe_config.SNIPE_URL}/hardware"
    method = requests.post
    payload['status_id'] = 2 #Ready to Deploy 
    payload['serial'] = 'AUTO-GENERATED'

# exec api
response = method(target_url, headers={**headers, 'Content-Type': 'application/json'}, json=payload, verify=False)

print(f'Status Code: {response.status_code}')
if args.debug:
    print(f'Response: {response.text}')

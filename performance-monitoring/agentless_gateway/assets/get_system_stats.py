#!/usr/bin/python3
import json
import logging
import os
import re
import socket
import subprocess
from logging.handlers import SysLogHandler
from pathlib import Path

top_cpu_attribute_map = {
    'us': 'user',
    'sy': 'system',
    'ni': 'nice',
    'id': 'idle',
    'wa': 'wait',
    'hi': 'hardware',
    'si': 'software',
    'st': 'steal_time',
}

def main():
    stats = {
        'event_type': 'agentless_gw',
        'disk': get_disk_stats(),
        'system': get_system_stats(),
        'cpu': get_cpu_stats(),
        'memory': get_memory_stats(),
        'network': get_network_stats(),
    }

    print(json.dumps(stats))

    try:
        logger = logging.getLogger('Logger')
        logger.setLevel(logging.INFO)
        handler = SysLogHandler(address=('localhost', 10667), facility=21, socktype=socket.SOCK_STREAM)
        logger.addHandler(handler)
        logger.info(json.dumps(stats) + "\n")
    except Exception:
        logging.exception("syslog failed")

def strim(str):
    return re.sub(r'\s{2,}', ' ', str).strip()

def get_network_stats():
    # General socket stats - not directly associated with a particular interface
    stats = {}

    for interface_path in Path("/sys/class/net").iterdir():
        interface_name = interface_path.name.strip()
        if interface_name.startswith('eth'):
            output = subprocess.run(['ifconfig', interface_name], capture_output=True).stdout.decode('utf-8').strip()
            ipaddress = "n/a"
            for iface in output.split('\n'):
                iface = strim(iface)
                if iface.startswith('inet '):
                    ipaddress = iface[len('inet '):].replace("addr:", "").split(" ")[0]
                    break

            stats[interface_name] = {
                'ipaddress': ipaddress,
            }

            for interface_stat_path in (interface_path / 'statistics').iterdir():
                value = interface_stat_path.read_text().strip()
                stats[interface_name][interface_stat_path.name] = int(value)

    return stats

def get_disk_stats():
    stats = {}

    for mount in Path('/proc/mounts').read_text().split('\n'):
        if mount.strip():
            mount = mount.split(" ")
            if mount[1].startswith("/"):
                output = subprocess.run(['df', mount[1]], capture_output=True).stdout.decode('utf-8').strip()
                mount_stats = output.split("\n")[1].split()
                stats[mount[1]] = {
                    'disk_capacity': int(mount_stats[1]),
                    'disk_used': int(mount_stats[2]),
                    'disk_available': int(mount_stats[3]),
                }

    def get_mount_for_path(path):
        while str(path) not in stats:
            path = path.parent
        return stats[str(path)]

    stats['JSONAR_DATADIR'] = {
        **get_mount_for_path(Path(os.environ['JSONAR_DATADIR'])),
        'path': os.environ['JSONAR_DATADIR'],
    }

    stats['JSONAR_LOCALDIR'] = {
        **get_mount_for_path(Path(os.environ['JSONAR_LOCALDIR'])),
        'path': os.environ['JSONAR_LOCALDIR'],
    }

    stats['JSONAR_LOGDIR'] = {
        **get_mount_for_path(Path(os.environ['JSONAR_LOGDIR'])),
        'path': os.environ['JSONAR_LOGDIR'],
    }

    return stats

def get_system_stats():
    stats = {
        'uptime': Path('/proc/uptime').read_text().split(' ')[0].split('.')[0],
    }
    return stats

def get_cpu_stats():
    stats = {
        'top': {'system': {}},
    }

    output = subprocess.run(['top', '-bn', '2'], capture_output=True).stdout.decode('utf-8').strip()
    for top_line in output.split('\n'):
        top_line = top_line.lower()
        if 'load average' in top_line:
            averages = top_line.split("load average: ")[1].split(', ')
            stats['top']['average'] = {
                '1': float(averages[0]),
                '5': float(averages[1]),
                '10': float(averages[2]),
            }
        elif top_line.startswith('%cpu(s)'):
            stats['top']['system']['used'] = 0.0
            for cpu_stat in top_line.split(':')[1].strip().split(','):
                cpu_stat = cpu_stat.strip().split(' ')
                stats['top']['system'][top_cpu_attribute_map[cpu_stat[1]]] = float(cpu_stat[0])
                if cpu_stat[1] != 'id':
                    stats['top']['system']['used'] += float(cpu_stat[0])

    return stats

def get_memory_stats():
    stats = {
        'mem': {},
        'swap': {},
    }
    output = subprocess.run(['top', '-bn', '2'], capture_output=True).stdout.decode('utf-8').strip()
    for top_line in output.split('\n'):
        top_line = top_line.lower()
        if 'mem :' in top_line:
            for mem_stat in top_line.split(':')[1].strip().split(','):
                mem_stat = mem_stat.strip().split(' ')
                if mem_stat[1] in ('total', 'free', 'used'):
                    stats['mem'][mem_stat[1]] = int(mem_stat[0])
        elif 'swap:' in top_line:
            for swap_stat in top_line.split(':')[1].strip().split(','):
                swap_stat = swap_stat.strip().split(' ')
                if swap_stat[1] in ('total', 'free', 'used'):
                    stats['swap'][swap_stat[1]] = int(swap_stat[0])

    return stats

if __name__ == '__main__':
    main()
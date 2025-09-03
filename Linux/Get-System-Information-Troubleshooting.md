# Linux Server Information Commands

## Operating System Information

### `cat /etc/os-release`
**Purpose**: Displays operating system identification data

**Usage**: 
```bash
cat /etc/os-release
```

**Output Example**:
```
NAME="Ubuntu"
VERSION="20.04.3 LTS (Focal Fossa)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 20.04.3 LTS"
VERSION_ID="20.04"
```

### `uname -a`
**Purpose**: Shows comprehensive system information

**Usage**: 
```bash
uname -a
```

**Parameters**:
- `-a`: Display all information
- `-s`: Kernel name
- `-r`: Kernel release
- `-v`: Kernel version
- `-m`: Machine hardware name

**Output Example**:
```
Linux server01 5.4.0-74-generic #83-Ubuntu SMP Sat May 8 02:35:39 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux
```

### `hostnamectl`
**Purpose**: Control and display system hostname and related settings

**Usage**: 
```bash
hostnamectl
```

**Output Example**:
```
   Static hostname: server01
         Icon name: computer-server
           Chassis: server
        Machine ID: abc123def456...
           Boot ID: xyz789...
  Operating System: Ubuntu 20.04.3 LTS
            Kernel: Linux 5.4.0-74-generic
      Architecture: x86-64
```

### `lsb_release -a`
**Purpose**: Displays Linux Standard Base information

**Usage**: 
```bash
lsb_release -a
```

**Parameters**:
- `-a`: All information
- `-d`: Description only
- `-r`: Release number only
- `-c`: Codename only

**Note**: May require installation of `lsb-release` package on some systems.

---

## Memory Information

### `free -h`
**Purpose**: Display memory usage in human-readable format

**Usage**: 
```bash
free -h
```

**Parameters**:
- `-h`: Human-readable format (KB, MB, GB)
- `-m`: Display in MB
- `-g`: Display in GB
- `-s N`: Update every N seconds

**Output Example**:
```
              total        used        free      shared  buff/cache   available
Mem:           15Gi       2.1Gi       8.9Gi       234Mi       4.2Gi        12Gi
Swap:         2.0Gi          0B       2.0Gi
```

### `cat /proc/meminfo`
**Purpose**: Detailed memory statistics from kernel

**Usage**: 
```bash
cat /proc/meminfo
```

### `dmidecode --type memory`
**Purpose**: Display physical memory module information

**Usage**: 
```bash
sudo dmidecode --type memory
```

---

## Storage Information

### `df -h`
**Purpose**: Display filesystem disk space usage

**Usage**: 
```bash
df -h
```

**Parameters**:
- `-h`: Human-readable format
- `-T`: Show filesystem type
- `-i`: Show inode information

**Output Example**:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        20G  8.2G   11G  44% /
/dev/sda2       100G   45G   50G  48% /home
tmpfs           7.8G     0  7.8G   0% /dev/shm
```

### `lsblk`
**Purpose**: List block devices in tree format

**Usage**: 
```bash
lsblk
```

**Parameters**:
- `-f`: Show filesystem information
- `-a`: Show all devices
- `-p`: Show full device paths

**Output Example**:
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0  120G  0 disk 
├─sda1   8:1    0   20G  0 part /
├─sda2   8:2    0  100G  0 part /home
└─sda3   8:3    0    2G  0 part [SWAP]
```

### `fdisk -l`
**Purpose**: List disk partitions and details

**Usage**: 
```bash
sudo fdisk -l
```

### `du -sh /*`
**Purpose**: Show disk usage by directory

**Usage**: 
```bash
du -sh /*
```

**Parameters**:
- `-s`: Summary only
- `-h`: Human-readable format
- `-a`: All files, not just directories
- `-x`: Stay on same filesystem

**Alternative for specific directory**:
```bash
du -sh /var/*
```
---

## CPU Information

### `cat /proc/cpuinfo`
**Purpose**: Display detailed processor information

**Usage**: 
```bash
cat /proc/cpuinfo
```

### `lscpu`
**Purpose**: Display CPU architecture information in organized format

**Usage**: 
```bash
lscpu
```

**Output Example**:
```
Architecture:                    x86_64
CPU op-mode(s):                  32-bit, 64-bit
Byte Order:                      Little Endian
CPU(s):                          8
On-line CPU(s) list:             0-7
Thread(s) per core:              2
Core(s) per socket:              4
Socket(s):                       1
NUMA node(s):                    1
Vendor ID:                       GenuineIntel
CPU family:                      6
Model:                           142
Model name:                      Intel(R) Core(TM) i7-8550U CPU @ 1.80GHz
Stepping:                        10
CPU MHz:                         1800.000
CPU max MHz:                     4000.0000
CPU min MHz:                     400.0000
```

### `nproc`
**Purpose**: Display number of processing units

**Usage**: 
```bash
nproc
```

**Parameters**:
- `--all`: Show all processing units
- `--ignore=N`: Ignore N processing units

---

## Network Information

### `ip addr show`
**Purpose**: Display network interface information (modern command)

**Usage**: 
```bash
ip addr show
ip a  # Short form
```

**Parameters**:
- `show eth0`: Show specific interface
- `-4`: Show IPv4 only
- `-6`: Show IPv6 only

---

### `ifconfig`
**Purpose**: Display network interface information (legacy command)

**Usage**: 
```bash
ifconfig
ifconfig eth0  # Specific interface
```

**Note**: May not be installed by default on newer systems. Install with:
```bash
# Ubuntu/Debian
sudo apt install net-tools

# CentOS/RHEL
sudo yum install net-tools
```

### `ss -tuln`
**Purpose**: Display listening network sockets

**Usage**: 
```bash
ss -tuln
```

**Parameters**:
- `-t`: TCP sockets
- `-u`: UDP sockets
- `-l`: Listening sockets only
- `-n`: Show numerical addresses instead of resolving hosts
- `-p`: Show process using socket (requires privileges)

### `netstat -tulnp`
**Purpose**: Display network connections (legacy alternative to ss)

**Usage**: 
```bash
netstat -tulnp
```

---

## System Overview

### `htop`
**Purpose**: Interactive process viewer and system monitor

**Usage**: 
```bash
htop
```

**Installation**: 
```bash
# Ubuntu/Debian
sudo apt install htop

# CentOS/RHEL
sudo yum install htop
```

### `top`
**Purpose**: Display running processes and system resources

**Usage**: 
```bash
top
```

**Key Shortcuts**:
- `q`: Quit
- `P`: Sort by CPU usage
- `M`: Sort by memory usage
- `k`: Kill process
- `1`: Show individual CPU cores

### `uptime`
**Purpose**: Show system uptime and load average

**Usage**: 
```bash
uptime
```

**Output Example**:
```
 15:30:25 up 5 days,  3:45,  2 users,  load average: 0.15, 0.25, 0.30
```

**Load Average Interpretation**:
- First number: 1-minute average
- Second number: 5-minute average
- Third number: 15-minute average
- Values > number of CPU cores indicate high load

### `who`
**Purpose**: Show currently logged-in users

**Usage**: 
```bash
who
```

**Parameters**:
- `-u`: Show idle time
- `-a`: Show all information

### `w`
**Purpose**: Show logged-in users and their activities

**Usage**: 
```bash
w
```

---

## Hardware Information

### `lshw`
**Purpose**: List comprehensive hardware information

**Usage**: 
```bash
sudo lshw
sudo lshw -short  # Condensed format
sudo lshw -html > hardware.html  # HTML report
```

**Parameters**:
- `-short`: Brief format
- `-html`: HTML output
- `-xml`: XML output
- `-class network`: Show specific hardware class

**Installation**: 
```bash
# Ubuntu/Debian
sudo apt install lshw

# CentOS/RHEL
sudo yum install lshw
```

### `lspci`
**Purpose**: List PCI devices

**Usage**: 
```bash
lspci
lspci -v  # Verbose output
```

**Parameters**:
- `-v`: Verbose
- `-vv`: Very verbose
- `-k`: Show kernel drivers

### `lsusb`
**Purpose**: List USB devices

**Usage**: 
```bash
lsusb
lsusb -v  # Verbose output
```

### `dmidecode`
**Purpose**: Display DMI/SMBIOS hardware information

**Usage**: 
```bash
sudo dmidecode
sudo dmidecode --type bios      # BIOS information
sudo dmidecode --type system    # System information
sudo dmidecode --type processor # CPU information
```

**Common Types**:
- `bios`: BIOS information
- `system`: System information
- `baseboard`: Motherboard information
- `chassis`: Chassis information
- `processor`: CPU information
- `memory`: RAM information

---

## Troubleshooting

### Common Issues and Solutions

#### High Memory Usage
- **Investigation Steps**:
  1. `free -h` - Check overall memory usage
  2. `top` or `htop` - Identify memory-consuming processes
  3. `cat /proc/meminfo` - Detailed memory breakdown
  4. `ps aux --sort=-%mem | head -10` - Top memory consumers

#### High Disk Usage
- **Investigation Steps**:
  1. `df -h` - Identify full partitions
  2. `du -sh /*` - Find large directories
  3. `find / -type f -size +100M 2>/dev/null` - Find large files
  4. `lsof +L1` - Find deleted files still open

#### High Load Average
- **Investigation Steps**:
  1. `uptime` - Check current load
  2. `top` - Identify CPU-intensive processes
  3. `iostat` - Check I/O wait (if available)
  4. `ps aux --sort=-%cpu | head` - Top CPU consumers

#### Network Issues
- **Investigation Steps**:
  1. `ip addr show` - Check interface configuration
  2. `ping -c 4 google.com` - Test connectivity
  3. `ss -tuln` - Check listening services
  4. `netstat -rn` - Check routing table

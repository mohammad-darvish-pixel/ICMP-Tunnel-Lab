# 🚀 ICMP Tunnel Lab

> A Windows-based security laboratory for understanding **ICMP Tunneling**, simulated data exfiltration, packet-level communication, and defensive network traffic analysis with **Wireshark**.

[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://github.com/mohammad-darvish-pixel/ICMP-Tunnel-Lab)
[![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python\&logoColor=white)](https://www.python.org/)
[![Scapy](https://img.shields.io/badge/Scapy-Packet%20Crafting-red)](https://scapy.net/)
[![Wireshark](https://img.shields.io/badge/Wireshark-Network%20Analysis-1679A7?logo=wireshark\&logoColor=white)](https://www.wireshark.org/)
[![License](https://img.shields.io/badge/Use-Authorized%20Lab%20Only-orange)](#-security-notice)

---

## ⚡ One-Command Setup

> **Run PowerShell as Administrator before executing the command below.**

```$u="https://github.com/mohammad-darvish-pixel/ICMP-Tunnel-Lab/archive/refs/heads/main.zip";$d="$env:USERPROFILE\Desktop\icmp-tunnel-lab";Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue;New-Item $d -ItemType Directory -Force|Out-Null;Invoke-WebRequest $u -OutFile "$d\lab.zip";Expand-Archive "$d\lab.zip" $d -Force;Remove-Item "$d\lab.zip" -Force;$p=Get-ChildItem $d -Directory|Select-Object -First 1;Set-Location $p.FullName;& powershell -ExecutionPolicy Bypass -File ".\launcher.ps1"```

### ⚠️ Security Warning

The command above **downloads code from GitHub and executes it with Administrator privileges**.

Only use it if you have reviewed and trust the repository.

**Never run unknown PowerShell installation commands with Administrator privileges.**

---

## 📌 Overview

**ICMP Tunnel Lab** is a controlled Windows laboratory for studying how data can be transported through **ICMP Echo Request packets**.

The project demonstrates a simplified communication flow:

```text
             Test File
                 │
                 ▼
          Base64 Encoding
                 │
                 ▼
          Split into Chunks
                 │
                 ▼
       ┌─────────────────────┐
       │   ICMP Echo Request │
       │       Packets        │
       └──────────┬──────────┘
                  │
                  ▼
             Receiver
                  │
                  ▼
          Reassemble Chunks
                  │
                  ▼
           Base64 Decode
                  │
                  ▼
          Reconstructed File
```

The project is intended for **security research, packet analysis, detection engineering, and controlled laboratory experimentation**.

---

## 🎯 What This Lab Demonstrates

This laboratory covers:

* ICMP Echo Requests
* ICMP payload manipulation
* Raw packet generation with Scapy
* Chunk-based data transfer
* Base64 encoding
* Packet reconstruction
* ICMP tunneling concepts
* Simulated data exfiltration
* Wireshark packet analysis
* Network traffic baselining
* Detection indicators for suspicious ICMP traffic

---

## 🧩 How the Tunnel Works

A normal ping generally looks like:

```text
Host A
   │
   │ ICMP Echo Request
   ▼
Host B
   │
   │ ICMP Echo Reply
   ▼
Host A
```

The laboratory uses ICMP as a transport mechanism:

```text
Sender
   │
   │ ICMP + Data
   ▼
Receiver
```

The data is divided into multiple chunks and placed inside ICMP Echo Request payloads.

The receiver identifies the laboratory packets, extracts the chunks, reconstructs the original Base64 stream, decodes it, and writes the resulting file to disk.

---

## 📦 Packet Format

The laboratory uses a recognizable packet structure:

```text
ICMP Echo Request
│
├── Identifier
│     └── 0x4C42
│
├── Sequence Number
│
└── Payload
      │
      ├── ICMTUN
      ├── Session ID
      ├── Sequence
      ├── Total Chunks
      ├── Filename
      └── Base64 Data
```

The logical payload format is:

```text
ICMTUN:<session>:<sequence>:<total>:<filename>:<base64_chunk>
```

This structure allows the receiver to associate packets with a transfer and reconstruct the original file.

---

## 🏗️ Architecture

```text
                    Windows Host
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
      sender.py      Receiver.py    Wireshark
          │              ▲
          │              │
          └── ICMP ──────┘
             Traffic
```

### Sender

`sender.py`:

1. Reads the test file.
2. Encodes the data using Base64.
3. Splits the data into chunks.
4. Creates ICMP Echo Requests.
5. Sends the packets sequentially.

### Receiver

`Receiver.py`:

1. Captures ICMP traffic.
2. Identifies laboratory packets.
3. Extracts transfer metadata.
4. Collects chunks.
5. Reconstructs the data.
6. Decodes the Base64 content.
7. Writes the reconstructed file.

### Wireshark

Wireshark provides visibility into the generated traffic and allows the packets to be investigated at the protocol and payload levels.

---

## 🖥️ Requirements

| Component      | Requirement             |
| -------------- | ----------------------- |
| OS             | Windows 10 / Windows 11 |
| Python         | 3.11+                   |
| Packet Library | Scapy                   |
| Packet Capture | Npcap                   |
| Analysis       | Wireshark               |
| Privileges     | Administrator           |

The included launcher performs the required environment checks.

---

## 🚀 Installation

### Option 1 — Automatic Launcher

Clone the repository:

```powershell
git clone https://github.com/mohammad-darvish-pixel/ICMP-Tunnel-Lab.git
```

Enter the directory:

```powershell
cd ICMP-Tunnel-Lab
```

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\launcher.ps1
```

---

### Option 2 — Batch Launcher

The repository also includes:

```text
start_lab.bat
```

Run it as Administrator if required.

---

## ▶️ Manual Execution

Start the receiver:

```powershell
python Receiver.py
```

Then start the sender:

```powershell
python sender.py
```

Or specify the target and file directly:

```powershell
python sender.py 127.0.0.1 secret.txt
```

The default laboratory configuration uses:

```text
Target:
127.0.0.1
```

This allows the entire experiment to run locally on a single Windows machine.

---

## 📁 Received Files

When the receiver successfully reconstructs a file, it creates:

```text
received/
```

The reconstructed file is stored using:

```text
received/recv_<filename>
```

For example:

```text
received/recv_secret.txt
```

---

# 🔬 Wireshark Analysis

Start Wireshark before sending the test file.

For the default local configuration, select the **Npcap Loopback Adapter**.

### Display ICMP

```text
icmp
```

### Echo Requests

```text
icmp.type == 8
```

### Echo Replies

```text
icmp.type == 0
```

### Laboratory Traffic

The laboratory uses:

```text
0x4C42
```

as its ICMP identifier.

Use:

```text
icmp[4:2] == 0x4c42
```

to isolate the laboratory traffic.

You can also search for the laboratory header:

```text
frame contains "ICMTUN"
```

---

## 🔎 What Should You Look For?

When analyzing the traffic, investigate multiple characteristics together.

### 1. Packet Frequency

The sender intentionally creates a regular packet stream.

```text
Packet
   │
   ├── delay
   ▼
Packet
   │
   ├── delay
   ▼
Packet
```

Regular periodic traffic can be useful when identifying unusual ICMP communication.

---

### 2. Payload Size

Compare the payload sizes of normal ICMP traffic with the laboratory traffic.

Repeated and highly structured payload sizes can become an investigation indicator.

---

### 3. Payload Content

Inspect the ICMP payload.

Instead of ordinary diagnostic data, the laboratory payload contains structured fields such as:

```text
ICMTUN
Session ID
Sequence
Total
Filename
Base64 Data
```

---

### 4. Identifier and Sequence

Inspect:

```text
Identifier
Sequence Number
```

The laboratory uses:

```text
Identifier = 0x4C42
```

and increments the sequence information as chunks are transmitted.

---

### 5. Communication Pattern

Look for combinations such as:

```text
Repeated ICMP
      +
Regular timing
      +
Structured payload
      +
Consistent packet sizes
      +
Unexpected destination
```

A single indicator does **not** prove that tunneling is occurring.

---

# 🛡️ Defensive Detection Perspective

From a defensive perspective, the interesting question is not simply:

> "Is ICMP being used?"

Instead, investigate:

> **"Is this ICMP traffic consistent with the normal behavior of this environment?"**

Potential indicators include:

```text
Unexpected ICMP volume
        +
Regular packet intervals
        +
Unusual payload sizes
        +
Structured payload content
        +
Long-lived communication
        +
Unexpected destinations
```

These characteristics should be evaluated against a known baseline.

Legitimate monitoring and diagnostic software can also generate unusual ICMP traffic.

---

# 🧪 Simulated Exfiltration

The laboratory uses synthetic data.

Example:

```text
LAB_SECRET
TRAINING_DATA
THIS_IS_A_TEST
```

The workflow is:

```text
secret.txt
    │
    ▼
Base64 Encode
    │
    ▼
Split into Chunks
    │
    ▼
ICMP Packets
    │
    ▼
Receiver
    │
    ▼
Reassemble
    │
    ▼
Decode
    │
    ▼
received/recv_secret.txt
```

**Do not use real credentials, confidential files, customer information, or other sensitive data.**

---

# 📂 Project Structure

```text
ICMP-Tunnel-Lab/
│
├── Receiver.py
├── sender.py
├── launcher.ps1
├── start_lab.bat
├── secret.txt
└── README.md
```

After a successful transfer:

```text
ICMP-Tunnel-Lab/
│
└── received/
    └── recv_secret.txt
```

---

# ⚙️ Laboratory Configuration

The current implementation uses:

| Parameter          |       Value |
| ------------------ | ----------: |
| Default Target     | `127.0.0.1` |
| Chunk Size         |  `32 bytes` |
| Inter-packet Delay |  `0.15 sec` |
| ICMP Identifier    |    `0x4C42` |
| Payload Header     |    `ICMTUN` |
| Encoding           |      Base64 |

These values make the laboratory traffic easy to identify and analyze.

---

# 🧠 Learning Objectives

After completing the laboratory, you should be able to understand:

* How ICMP Echo packets work
* Where ICMP payload data exists
* How raw packets can be generated with Scapy
* How data can be divided into packet-sized chunks
* How a receiver can reconstruct those chunks
* How ICMP tunneling works conceptually
* How simulated exfiltration can appear in packet captures
* How to investigate ICMP traffic in Wireshark
* How to establish an ICMP traffic baseline
* How multiple network indicators can be combined during an investigation

---

# ⚠️ Security Notice

This project is intended for **authorized security research and controlled laboratory environments**.

Do not use it to:

* Exfiltrate real confidential information
* Transfer credentials
* Bypass security controls
* Establish unauthorized tunnels
* Evade monitoring
* Access systems without authorization
* Conduct unauthorized security testing

Use synthetic laboratory data such as:

```text
LAB_SECRET
TRAINING_DATA
TEST_FILE
```

---

# 📜 Disclaimer

This project is provided for educational, research, and defensive network-analysis purposes.

The author is not responsible for misuse of this project or any damage resulting from unauthorized use.

---

## 🔗 Repository

**ICMP-Tunnel-Lab**

https://github.com/mohammad-darvish-pixel/ICMP-Tunnel-Lab

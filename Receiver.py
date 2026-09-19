#!/usr/bin/env python3
"""
ICMP Tunnel Receiver — Blue Team Lab (Windows)
===============================================
Sniffs ICMP Echo Requests and reconstructs exfiltrated data.

Requirements : Python 3.x  |  Scapy  |  Npcap (with loopback support)
Run via      : start_lab.bat  (recommended)
Or manually  : Run PowerShell as Administrator → python receiver.py
"""

import os
import sys
import base64
import ctypes
from datetime import datetime

# ── Config ────────────────────────────────────────────────────────────────────
MAGIC_HDR  = "ICMTUN"    # Identifies tunnel packets in payload
MAGIC_ID   = 0x4C42      # ICMP Identifier (Wireshark: icmp[4:2] == 0x4c42)
OUTPUT_DIR = "received"  # Folder where reconstructed files are saved
# ─────────────────────────────────────────────────────────────────────────────

sessions: dict = {}       # session_id → {chunks, total, src, filename, timestamp}


# ── Admin / Privilege Check ───────────────────────────────────────────────────
def is_admin() -> bool:
    """Check for Windows Administrator privileges."""
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


# ── Loopback Interface Detection ─────────────────────────────────────────────
def find_loopback_iface():
    """
    Find the Npcap loopback interface on Windows.
    With Npcap installed, this is usually '\\Device\\NPF_Loopback'.
    Falls back to all interfaces if not found.
    """
    try:
        from scapy.all import get_if_list, IFACES

        all_ifaces = get_if_list()

        # Priority 1: NPF_Loopback by name
        for name in all_ifaces:
            if "Loopback" in name or "loopback" in name.lower():
                print(f"[*] Loopback iface : {name}")
                return name

        # Priority 2: Check IFACES descriptions (friendly names)
        for name, obj in IFACES.items():
            desc = str(getattr(obj, "description", "")).lower()
            if "loopback" in desc:
                print(f"[*] Loopback iface : {name}  ({getattr(obj, 'description', '')})")
                return name

        # Fallback: sniff everything
        print("[!] Loopback interface not found — sniffing ALL interfaces.")
        print("[!] If Npcap is freshly installed, try restarting this script.")
        return all_ifaces

    except Exception as e:
        print(f"[-] Interface detection error: {e}")
        return None


# ── Banner ────────────────────────────────────────────────────────────────────
def banner():
    print("""
  ╔══════════════════════════════════════════════════════╗
  ║   ICMP Tunnel Receiver — Blue Team Lab (Windows)     ║
  ║   Waiting for incoming ICMP tunnel packets...        ║
  ╚══════════════════════════════════════════════════════╝
""")


# ── File Reconstruction ───────────────────────────────────────────────────────
def reconstruct(session_id: str) -> None:
    """Assemble all chunks and write the reconstructed file to disk."""
    sess = sessions[session_id]
    print(f"\n\n[*] Reconstructing data  (session: {session_id}) ...")

    try:
        full_b64 = "".join(sess["chunks"][i] for i in range(sess["total"]))
        data = base64.b64decode(full_b64)

        os.makedirs(OUTPUT_DIR, exist_ok=True)
        out_path = os.path.join(OUTPUT_DIR, f"recv_{sess['filename']}")
        with open(out_path, "wb") as fh:
            fh.write(data)

        elapsed = (datetime.now() - sess["timestamp"]).total_seconds()
        print(f"[+] File saved  : {os.path.abspath(out_path)}")
        print(f"[+] Size        : {len(data)} bytes")
        print(f"[+] Source IP   : {sess['src']}")
        print(f"[+] Duration    : {elapsed:.2f}s  ({sess['total']} packets)")

        try:
            preview = data[:150].decode("utf-8", errors="replace")
            print(f"[+] Preview:\n    {preview}")
        except Exception:
            pass
        print()

    except KeyError as e:
        print(f"[-] Missing chunk {e} — transfer incomplete!")
    except Exception as e:
        print(f"[-] Reconstruction error: {e}")
    finally:
        del sessions[session_id]


# ── Packet Callback ───────────────────────────────────────────────────────────
def process_packet(pkt) -> None:
    """Called by Scapy for every captured ICMP packet."""
    try:
        from scapy.all import ICMP, IP, Raw
    except ImportError:
        return

    if not (pkt.haslayer(ICMP) and pkt.haslayer(Raw)):
        return

    icmp = pkt[ICMP]
    # We only care about Echo Requests with our magic identifier
    if icmp.type != 8 or icmp.id != MAGIC_ID:
        return

    try:
        raw_payload = pkt[Raw].load.decode("utf-8", errors="ignore")

        # Wire format: ICMTUN:<session_id>:<seq>:<total>:<filename>:<b64_chunk>
        parts = raw_payload.split(":", 5)
        if len(parts) != 6 or parts[0] != MAGIC_HDR:
            return

        _, session_id, seq_s, total_s, filename, chunk = parts
        seq   = int(seq_s)
        total = int(total_s)
        src   = pkt[IP].src

        if session_id not in sessions:
            sessions[session_id] = {
                "chunks":    {},
                "total":     total,
                "src":       src,
                "filename":  filename,
                "timestamp": datetime.now(),
            }
            print(f"\n[+] === New Exfiltration Session ===")
            print(f"    Session ID  : {session_id}")
            print(f"    Source IP   : {src}")
            print(f"    Filename    : {filename}")
            print(f"    Total pkts  : {total}")

        sessions[session_id]["chunks"][seq] = chunk
        received = len(sessions[session_id]["chunks"])
        bar = "=" * int(received / total * 35)
        sys.stdout.write(f"\r    Progress   : [{bar:<35}] {received}/{total}")
        sys.stdout.flush()

        if received >= total:
            reconstruct(session_id)

    except Exception:
        pass  # Silently ignore packets we can't parse


# ── Main ─────────────────────────────────────────────────────────────────────
def main() -> None:
    if not is_admin():
        print("""
  [-] Administrator privileges required!
      This script needs raw socket access.

  Options:
    1. Use start_lab.bat  (recommended — handles everything)
    2. Right-click PowerShell → Run as Administrator
       Then: python receiver.py
""")
        input("  Press Enter to exit...")
        sys.exit(1)

    try:
        from scapy.all import sniff
    except ImportError:
        sys.exit("[-] Scapy not installed! Run: pip install scapy")

    banner()

    iface = find_loopback_iface()

    print(f"[*] ICMP magic ID  : 0x{MAGIC_ID:04X}")
    print(f"[*] Output dir     : {os.path.abspath(OUTPUT_DIR)}")
    print()
    print("[*] Wireshark filters:")
    print(f"    Tunnel packets  : icmp[4:2] == 0x{MAGIC_ID:04x}")
    print(f"    Echo Requests   : icmp.type == 8")
    print(f"    Payload search  : frame contains \"ICMTUN\"")
    print()
    print("    Wireshark interface: 'Adapter for loopback traffic capture'")
    print()
    print("[*] Listening... Press Ctrl+C to stop.\n")

    try:
        sniff(filter="icmp", iface=iface, prn=process_packet, store=0)
    except KeyboardInterrupt:
        print("\n[*] Receiver stopped.")
    except Exception as e:
        print(f"\n[-] Sniff error: {e}")
        print("    Make sure Npcap is installed with loopback support enabled.")
        input("    Press Enter to exit...")


if __name__ == "__main__":
    main()
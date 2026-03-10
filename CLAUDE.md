# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **knowledge base (KBS)** of enterprise IT infrastructure solutions — each subdirectory is a self-contained project with its own README, configuration examples, logs, and supporting files. There is no unified build system.

## Repository Structure

Each top-level directory is an independent project:

| Category | Directories |
|---|---|
| Authentication & Identity | `ikev2/`, `ntlmv2/`, `radsecproxy/`, `radiustls13/`, `hostap/`, `oidc/`, `kerecer/` |
| Enterprise Security | `Fortigate/`, `PAVM/`, `firewall.sh`, `nftables.conf` |
| Identity Management | `websignin/`, `maonprem/`, `intune/` |
| Database & HA | `sds/` (SymmetricDS), `sqlcluster/` |
| Web Services | `discourse/`, `webpack-svg-inline/`, `OOF/` |
| Monitoring & Diagnostics | `watchglowroot/`, `ranports/` |
| Build Automation | `sln2cmake/` |
| Other | `dualsession/` |

## Runnable Code

Most content is documentation. Executable components:

- **PowerShell** (`intune/`): `Deploy.ps1`, `Deploy2.ps1`, `Remove.ps1`, `detection_rule.ps1` — Intune Win32 app deployment scripts
- **Java** (`ranports/AgentPremain.java`): Byte Buddy Java agent for tracing `SocketChannel.connect()` calls; compile with standard `javac` and package as a JAR with `Premain-Class` manifest attribute
- **Shell** (`firewall.sh`, `nftables.conf`): Linux firewall configuration; run as root with `bash firewall.sh`

## Architecture Patterns

**Authentication flow**: Client → IKEv2/EAP → RADIUS (DualShield/FreeRADIUS) → MSCHAPv2/MPPE key generation → VPN gateway (pfSense/strongSwan/FortiClient)

**Database replication**: MySQL ↔ SymmetricDS node (TLS) ↔ SymmetricDS node (TLS) ↔ MySQL — bidirectional multi-master replication

**SQL Server HA**: Two-node failover cluster on ESXi with shared SCSI disk and a VIP (MAC-address-based routing to active node)

**RADIUS proxy chain**: Client → radsecproxy (UDP→TLS bridge) → DualShield → response back over TLS

**GlobalProtect/Palo Alto**: GlobalProtect client → PAVM (ethernet1/1) → RADIUS auth (DualShield) → IKEv2/IPSec tunnel

## Key Technical Notes

- **ikev2**: Documents a known issue where MSK generation differs between DualShield and strongSwan when using MSCHAPv2; includes packet capture analysis
- **sds**: SymmetricDS configuration handles foreign key constraint violations during initial load via `initial.load.delete.first=true`
- **sqlcluster**: VIP resolution relies on static ARP entries; the active node responds to the VIP MAC address
- **radsecproxy**: Bridges UDP RADIUS to TLS RADIUS; certificate pinning configured per-realm
- **hostap**: Uses `hostapd` + `wpa_supplicant` to create a virtual wired EAP test environment without physical switches
- **maonprem**: Modern Authentication for on-premises Exchange requires ADFS with OAuth2 token endpoint configuration

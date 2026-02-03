# PA-VM (Palo Alto VM-Series) installation notes

This is a practical, “get it running” checklist for deploying a Palo Alto **VM-Series** firewall (PA-VM) in a lab. It focuses on:

- Getting the image from the right place
- Importing/booting on a hypervisor (ESXi or Proxmox)
- Doing the first boot management configuration
- Common pitfalls (NIC mapping, licensing, time sync, commit errors)

If you’re doing this for production, follow Palo Alto’s official documentation and support guidance for your target hypervisor.

## 1) Choose the right image

### Official download (recommended)
Use the Palo Alto **Support Portal** / official channels to obtain the VM-Series image for your hypervisor:

- **ESXi/vSphere**: OVA/OVF
- **KVM**: qcow2 / KVM bundle

> Note: If you are running **Proxmox (KVM)**, prefer a **KVM image** when available. Importing an ESXi OVA into Proxmox can work for labs, but may not match Palo Alto’s supported matrix.

### Mirror download (lab convenience)
I used `PA-VM-ESX-11.1.4.ova` from:

- https://mirror.cloudpropeller.com/paloalto/vm-series/

If you download from anywhere other than the official portal:

- Validate checksums/signatures if provided
- Keep a copy of the exact filename/version you deployed

## 2) Sizing and prerequisites (quick checklist)

Before import, decide:

- **Model / license tier** (affects throughput/features)
- **CPU/RAM** sizing per Palo Alto guidance for your VM-Series model
- **Interfaces**: management vs dataplane NICs, VLAN plan
- **Bootstrap or manual config** (bootstrap makes repeatable lab deploys)

Practical lab baseline that usually boots fine:

- vCPU: 2–4
- RAM: 4–8 GB
- Disk: per image default + log growth

## 3) ESXi import (high level)

If you’re on ESXi/vSphere:

- Deploy OVF/OVA using vSphere UI
- Verify NIC types per Palo Alto guidance (vmxnet3 is common on VMware)
- Boot, then do initial config (see below)

Official reference:

- [VM-Series Deployment Guide (ESXi)](https://docs.paloaltonetworks.com/vm-series/11-0/vm-series-deployment/set-up-a-vm-series-firewall-on-an-esxi-server/install-a-vm-series-firewall-on-vmware-vsphere-hypervisor-esxi/perform-initial-configuration-on-the-vm-series-on-esxi)

## 4) Proxmox import (OVA → VM)

OVA is VMware format. Proxmox can import it, but there are a few “gotchas”.

### Storage requirement
Make sure the target Proxmox storage supports **Disk image** content.

If it doesn’t, Proxmox may fail during import or when attaching the disk.

### Example import workflow (CLI)

This is a common pattern (adjust storage name/VMID):

1) Upload the OVA to your Proxmox host (or place it on shared storage)
2) Create an empty VM shell
3) Import the OVA disk
4) Attach the imported disk and set boot order

Example commands:

```bash
# Pick an unused VMID
VMID=120

# Create VM (no disk yet)
qm create $VMID --name pa-vm --memory 8192 --cores 4 --net0 virtio,bridge=vmbr0

# Import the OVA/OVF disk into a storage that supports 'Disk image'
qm importovf $VMID /path/to/PA-VM-ESX-11.1.4.ova <your-storage-name>

# Then review the VM hardware in the UI:
# - set boot order to the imported disk
# - verify SCSI controller type
# - add additional NICs for dataplane (net1/net2/...) as needed
```

If you prefer a UI-driven guide:

- [Creating a Proxmox VM from an OVA](https://doc.haivision.com/HMG/4.1/creating-a-proxmox-vm-from-an-iso)

### NIC mapping tip
In many PAN-OS setups:

- `mgmt` is a dedicated management interface
- `ethernet1/1`, `ethernet1/2`, … are dataplane

Be deliberate about which Proxmox bridge each NIC connects to (e.g., `vmbr-mgmt` vs `vmbr-wan` vs `vmbr-lan`). Label them in Proxmox so you don’t “lose” the management interface after committing network changes.

## 5) First boot / initial management configuration

After the VM boots, use the console to set up management connectivity.

### Set management IP (CLI)

```text
configure
set deviceconfig system type static
set deviceconfig system ip-address <FIREWALL_MGMT_IP> netmask <NETMASK> default-gateway <GATEWAY_IP>
set deviceconfig system dns-setting servers primary <DNS_IP>
commit
```

Then browse:

- `https://<FIREWALL_MGMT_IP>`

### Time and DNS matter
Licensing, updates, and many TLS-related operations are sensitive to time.

At minimum:

- Ensure DNS resolves
- Configure NTP (or at least confirm time is correct)

## 6) Licensing and content updates (post-boot)

Typical order:

1) Apply license/auth codes (or attach license if your model uses that flow)
2) Install the latest **Apps + Threats** / content updates
3) Optionally update PAN-OS to your desired target version

If you can’t reach the update servers, verify:

- Default gateway / routing
- DNS
- NTP/time
- Upstream firewall rules

## 7) Basic network setup (sanity steps)

Minimal “smoke test” once management is reachable:

- Create at least one dataplane interface (`ethernet1/1`) and put it in a zone
- Configure a virtual router + routes
- Add security policy permitting test traffic
- Add NAT if needed for outbound

Helpful walkthrough:

- [Palo Alto Firewalls - Basic Network Setup](https://www.wiresandwi.fi/blog/palo-alto-basic-setup)

## 8) Troubleshooting quick hits

### Can’t reach `https://<mgmt-ip>`

- Confirm the management IP/gateway/netmask with `show interface management`
- Confirm the VM NIC is connected to the right Proxmox/ESXi network
- Verify no IP conflict on the network

### Commit fails after changing networking

- If you moved the management interface to a new network/VLAN, you may have “stranded” yourself
- Use the console to revert/adjust mgmt settings

### Import/attach disk fails in Proxmox

- Ensure the target storage supports **Disk image**
- Re-run import to a supported storage and re-attach

## 9) Notes to improve repeatability (optional)

If you deploy often, consider:

- Using a dedicated Proxmox bridge for management (`vmbr-mgmt`)
- Keeping a “golden” VM template and cloning
- Using Palo Alto **bootstrap** configuration to automate initial config

# GlobalProtect Portal

## 1) Goal and Prerequisites

**Goal**: Configure GlobalProtect on an interface (e.g., `192.168.190.21`) in the same subnet as Management (`192.168.190.20`) to test RADIUS authentication.

**Prerequisites**:
- A running RADIUS server reachable by the Firewall.
- Access to proper hypervisor networking to put connection `ethernet1/1` on the same bridge as `Management`.

## 2) Quick Setup Steps

### Step 1: Certificate (Self-Signed)
GlobalProtect requires SSL.

1.  **Device > Certificate Management > Certificates**.
2.  Generate a **Root CA** (Name: `Root-CA`, Common Name: `Root-CA`, CA: `Yes`).
3.  Generate a **Server Cert** (Name: `GP-Cert`, Common Name: `192.168.190.21`, Signed By: `Root-CA`).
4.  **Device > Certificate Management > SSL/TLS Service Profile**.
5.  Create `GP-SSL-Profile` referencing `GP-Cert`.

### Step 2: Network Interface
1.  **Network > Interfaces > Ethernet > ethernet1/1**.
2.  **Interface Type**: `Layer3`.
3.  **Config Tab**: Assign to default **Virtual Router** and a **Security Zone** (e.g., `Untrust`).
4.  **IPv4 Tab**: add `192.168.190.21/24`.
5.  **Advanced Tab > Management Profile**: Create/Select one enabling `Ping` (to verify connectivity).

### Step 3: RADIUS & Auth Profile
1.  **Device > Server Profiles > RADIUS**: Add your RADIUS server IP and Shared Secret.
2.  **Device > Authentication Profile**: Create `GP-RADIUS-Auth`, type `RADIUS`, select your Server Profile. Add `all` to Allow List.

### Step 4: Portal & Gateway
**Portal**:
1.  **Network > GlobalProtect > Portals > Add**.
2.  **General**: Interface `ethernet1/1` (`192.168.190.21`).
3.  **Authentication**: Use `GP-SSL-Profile` and Add Client Auth sending to `GP-RADIUS-Auth`.
4.  **Agent**: Configure generic Agent settings. Add `External Gateway` pointing to `192.168.190.21`.

**Gateway**:
1.  **Network > GlobalProtect > Gateways > Add**.
2.  **General**: Interface `ethernet1/1` (`192.168.190.21`).
3.  **Authentication**: Use `GP-SSL-Profile` and Add Client Auth sending to `GP-RADIUS-Auth`.
4.  **Agent > Tunnel Settings**: Check Tunnel Mode. Assign IP Pool (e.g., `172.16.10.1-172.16.10.20`).

### Step 5: Commit & Test
1.  **Commit**.
2.  Test login via `https://192.168.190.21` or GlobalProtect Agent.
3.  Check **Monitor > Logs > System** (for Radius server-level errors) or **GlobalProtect** logs.

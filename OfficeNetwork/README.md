# Office Network

We have 2 offices. Both rely on building-managed Internet, so we should assume:

- no control over the upstream router
- NAT is present
- public IP addresses may change
- inbound port forwarding may not be available

At the same time, we already have dedicated cloud machines and public IP addresses at OVH.

The clean solution is to use OVH as a VPN hub and make each office connect out to it. Home users connect to the same hub as road-warrior clients.

# Recommended Design

Use a hub-and-spoke VPN:

- one small VPN gateway in OVH with a static public IP
- one VPN gateway appliance in Office A
- one VPN gateway appliance in Office B
- optional VPN clients for work-from-home users

The most practical protocol here is WireGuard.

Why WireGuard fits this case:

- each office only needs outbound Internet access
- it works well behind NAT
- configuration is simpler than full IPsec for small environments
- home-user support is straightforward
- performance is usually better than OpenVPN on small appliances

If your security policy requires IPsec, the same topology still applies, but WireGuard is the simpler and more reliable first choice for offices sitting behind third-party building Internet.

# Topology

```text
										Internet
												|
								OVH VPN Hub / Router
								 Public IP: x.x.x.x
							 WG transit: 10.200.0.1/24
									/        |        \
								 /         |         \
								/          |          \
							 /           |           \
			Office A Gateway   Office B     Home Users
			10.200.0.2         Gateway      10.200.0.100+
			LAN 192.168.10.0   10.200.0.3
			/24                LAN 192.168.20.0/24
```

Traffic model:

- Office A to Office B flows through the OVH hub
- Home users reach both office LANs through the OVH hub
- Internet breakout stays local at each office unless you explicitly choose full-tunnel VPN for users

# Target Addressing

Example addressing plan:

| Segment | Example |
| --- | --- |
| Office A LAN | 192.168.10.0/24 |
| Office B LAN | 192.168.20.0/24 |
| WireGuard transit | 10.200.0.0/24 |
| OVH hub | 10.200.0.1 |
| Office A gateway tunnel IP | 10.200.0.2 |
| Office B gateway tunnel IP | 10.200.0.3 |
| Home users | 10.200.0.100-10.200.0.199 |

Avoid overlapping office LAN ranges. If both offices currently use the same subnet, renumber one side before building the VPN. That is the single most common blocker in small site-to-site designs.

# Components

## OVH Hub

Use a small Linux VM in OVH:

- Ubuntu or Debian
- one public IP
- WireGuard installed
- IP forwarding enabled
- firewall rules restricted to VPN ports and expected routed traffic

This hub is not just a VPN endpoint. It is also the router between:

- Office A LAN
- Office B LAN
- remote users

## Office Gateways

Each office needs a device that can maintain an outbound WireGuard tunnel continuously.

Practical choices:

- OPNsense or pfSense appliance
- MikroTik router
- small Linux box
- a firewall already present onsite, if it supports WireGuard well

That office gateway advertises its local LAN to the OVH hub.

If Office A uses 5G as a backup WAN, the same overall VPN design still applies. The main difference is that the Office A gateway should handle dual uplinks:

- primary WAN: building-managed Internet
- secondary WAN: 5G broadband

This does not require a different OVH topology. Office A still initiates an outbound tunnel to the OVH hub. When failover happens, Office A may simply appear from a different public source IP.

That is usually acceptable for WireGuard because the Office A peer keeps dialing out to the same OVH endpoint.

## Linux VM as Office Gateway

A Linux VM is acceptable as the office gateway if it is deployed as a real routed gateway, not just as a host that happens to have a WireGuard client.

What the Linux VM must do:

- maintain the outbound WireGuard tunnel continuously
- forward traffic between the office LAN and the WireGuard interface
- advertise the office LAN subnet to the OVH hub
- receive routed traffic for remote subnets from office clients or the local router
- keep firewall and forwarding rules persistent across reboot

In practice, there are two workable patterns.

Pattern 1: the Linux VM is the office gateway for the relevant subnet.

- office devices use the Linux VM directly as their router, or
- the Linux VM sits inline between the office LAN and the upstream Internet edge

This is the cleanest model because routing is explicit.

Pattern 2: the Linux VM is an internal routed gateway behind an existing office router.

- the existing office router remains the default gateway for Internet access
- static routes are added so remote office subnets point to the Linux VM

Example:

- Office A LAN: 192.168.10.0/24
- Office A Linux VM: 192.168.10.2
- existing office router: 192.168.10.1
- add a route on the office router so 192.168.20.0/24 goes to 192.168.10.2

This works well if the local router allows custom static routes.

When a Linux VM is a good fit:

- you already run a stable hypervisor onsite
- you can control Linux routing and firewall policy
- you can add static routes on the existing office router, or place the VM inline
- you want a low-cost proof of concept or a lightweight production gateway

When a Linux VM is a poor fit:

- you cannot change routes on the office network
- the VM platform is less reliable than a dedicated network appliance
- you need simple dual-WAN, failover, and monitoring with minimal custom work
- the office network team wants an appliance-style firewall instead of a general-purpose server

Minimum Linux requirements:

- `net.ipv4.ip_forward=1`
- a persistent firewall policy using `nftables` or `iptables`
- WireGuard configured as a system service
- route persistence after reboot
- monitoring for tunnel state and VM health

Important limitation:

If the Linux VM cannot become the next hop for remote office subnets, then it is only a VPN client for itself, not an office gateway for the rest of the site.

For Office A with unstable building Internet plus 5G backup, a Linux VM can still work, but a dedicated firewall distribution such as OPNsense or pfSense is usually easier to operate for WAN failover.

## Home Users

Each home user installs the WireGuard client on:

- Windows
- macOS
- Linux
- iPhone
- Android

Home users should only receive routes for internal networks, for example:

- 192.168.10.0/24
- 192.168.20.0/24
- optionally 10.200.0.0/24 for management

This keeps the user on split tunnel and avoids forcing all Internet traffic through OVH.

# Routing Logic

The core idea is simple.

On the OVH hub:

- route 192.168.10.0/24 to Office A peer
- route 192.168.20.0/24 to Office B peer
- route remote-user client IPs to their respective peers

On Office A gateway:

- local LAN remains 192.168.10.0/24
- route 192.168.20.0/24 through the WireGuard tunnel
- route remote-user VPN range through the WireGuard tunnel if office hosts must initiate connections back to users

On Office B gateway:

- local LAN remains 192.168.20.0/24
- route 192.168.10.0/24 through the WireGuard tunnel

Do not NAT traffic between the office LANs unless there is no alternative. Routed VPN is cleaner, easier to troubleshoot, and preserves source IP visibility.

# Security Rules

At minimum, enforce these controls:

- only allow UDP 51820 or your chosen WireGuard port to the OVH hub
- allow forwarding only between known internal subnets
- deny VPN clients from reaching the public Internet through the hub unless explicitly required
- restrict remote users to only the internal services they need
- use separate keys per office gateway and per user device
- remove keys immediately when a user or device is retired

Recommended additions:

- MFA for user onboarding and key distribution process
- DNS hosted centrally or conditional DNS forwarding between offices
- monitoring on the OVH hub for tunnel health
- configuration backup for the office gateways

# High-Level Build Steps

## 1. Prepare the Office Networks

Confirm:

- Office A LAN subnet
- Office B LAN subnet
- no overlap between them
- the IP address of the gateway device in each office
- which internal servers need cross-office access

If Office A has a backup 5G link, also confirm:

- whether the gateway supports automatic WAN failover
- whether 5G is presented as Ethernet, DHCP, or USB tethering
- whether the 5G provider uses CGNAT
- whether Office A should fail back automatically when the primary WAN recovers

## 2. Build the OVH Hub

Install:

- WireGuard
- nftables or iptables

Enable routing:

```bash
sysctl -w net.ipv4.ip_forward=1
```

Persist it in `/etc/sysctl.conf`:

```text
net.ipv4.ip_forward=1
```

## 3. Connect Office A and Office B

Each office gateway initiates an outbound tunnel to OVH.

Allowed routes example:

- Office A peer on hub: 192.168.10.0/24
- Office B peer on hub: 192.168.20.0/24

On each office gateway, add the opposite office subnet as routed over the tunnel.

## 4. Add Remote Users

Create one WireGuard peer per user device.

Give each user:

- one tunnel IP
- routes only for the office subnets they need
- DNS pointing to an internal resolver if internal names are required

## 5. Lock Down Access

After connectivity works, apply least privilege:

- allow users only to the required ports
- block lateral movement where unnecessary
- separate admin access from ordinary office-user access

# Example WireGuard Intent

This is not a full production config, but it shows the shape of the design.

OVH hub concept:

```ini
[Interface]
Address = 10.200.0.1/24
ListenPort = 51820
PrivateKey = <hub-private-key>

[Peer]
# Office A gateway
PublicKey = <office-a-public-key>
AllowedIPs = 10.200.0.2/32, 192.168.10.0/24

[Peer]
# Office B gateway
PublicKey = <office-b-public-key>
AllowedIPs = 10.200.0.3/32, 192.168.20.0/24

[Peer]
# Example home user
PublicKey = <user1-public-key>
AllowedIPs = 10.200.0.101/32
```

Office A concept:

```ini
[Interface]
Address = 10.200.0.2/24
PrivateKey = <office-a-private-key>

[Peer]
PublicKey = <hub-public-key>
Endpoint = <ovh-public-ip>:51820
AllowedIPs = 10.200.0.0/24, 192.168.20.0/24
PersistentKeepalive = 25
```

Home user concept:

```ini
[Interface]
Address = 10.200.0.101/24
PrivateKey = <user-private-key>
DNS = 192.168.10.10

[Peer]
PublicKey = <hub-public-key>
Endpoint = <ovh-public-ip>:51820
AllowedIPs = 192.168.10.0/24, 192.168.20.0/24
PersistentKeepalive = 25
```

`PersistentKeepalive = 25` matters for peers behind NAT, which is likely true for both offices and many home users.

# Operational Notes

## DNS

If users need to access servers by name instead of IP, decide early how name resolution will work:

- one central DNS server reachable through the VPN
- conditional forwarders between the two office DNS servers
- split-DNS for home users

Without this, the VPN may be up while applications still appear broken.

## MTU

If file transfer works poorly or some applications hang, check MTU/MSS. This is common when traffic crosses multiple NAT layers or PPPoE links.

This matters even more on 5G backup links, where carrier NAT and encapsulation overhead can differ from the primary WAN.

## 5G Backup at Office A

Using 5G as a backup for Office A is a normal extension of this design. The configuration is mostly similar.

What stays the same:

- OVH remains the central hub
- Office B configuration is unchanged
- Office A still builds an outbound tunnel to OVH
- home users still connect to OVH, not directly to Office A
- routed subnets stay the same

What changes at Office A:

- the office gateway needs dual-WAN or WAN failover support
- health checks should decide when to switch from building Internet to 5G
- the WireGuard tunnel should be bound so it can re-establish over either uplink
- firewall rules must allow outbound VPN traffic on both uplinks

Important 5G-specific notes:

- many 5G providers use CGNAT, but that is fine here because Office A only needs outbound VPN connectivity
- do not design anything that depends on inbound connections to Office A over 5G
- expect different latency and lower stability during failover or cell congestion
- if billing is usage-based, avoid sending general Internet traffic over the VPN during 5G backup

Recommended behavior:

- keep split tunnel for users
- keep Internet breakout local at Office A even during backup mode
- only send traffic for private office subnets across the VPN
- use `PersistentKeepalive = 25` so the tunnel re-establishes quickly after WAN change

From a routing perspective, nothing fundamental changes. The main operational difference is that Office A's default route to the Internet may switch, causing the tunnel to re-form from a new source IP.

That is why an OVH hub with a fixed public IP is still the right anchor point.

## Monitoring

Monitor:

- last handshake time
- traffic counters
- tunnel endpoint reachability
- CPU and bandwidth on the OVH hub

## Availability

If this becomes business critical, add:

- a second OVH VPN hub in another availability zone or region
- configuration automation
- documented key rotation process

# Why This Is Better Than Exposing Office Services Directly

Using OVH as a VPN bridge gives:

- private connectivity between offices without depending on building network changes
- one controlled entry point for home workers
- no need to expose internal services directly to the Internet
- simpler future expansion if a third office appears

# Recommended Final Architecture

For this scenario, the best default answer is:

1. deploy one small OVH Linux VM as a WireGuard hub
2. deploy one VPN gateway appliance in each office
3. route office-to-office traffic through the OVH hub
4. onboard home users as individual WireGuard peers
5. keep Internet breakout local and only route private subnets through the VPN

That gives you a practical site-to-site style network plus remote access, without requiring control over the building-managed Internet connection.

# Optional Next Step

If needed, this can be expanded into a concrete implementation guide for:

- Ubuntu on OVH as the hub
- OPNsense or pfSense in each office
- Windows client setup for home users
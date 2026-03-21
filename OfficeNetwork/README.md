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
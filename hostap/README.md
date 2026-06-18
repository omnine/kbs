# Virtual Access Point - Wired EAP Lab
In order to test RADIUS authentication with EAP-PEAP, generally a physical WIFI access point is needed.
## Lab

| Machine | Roles |
| ----    | ----  |
| 192.168.190.62 (Ubuntu 24.04) | Access Point hostapd (the wired authenticator) |
| 192.168.190.37 (Ubuntu 24.04) | Supplicant wpa_supplicant, radius |

## hostapd Installation

The Ubuntu package already includes the wired driver (`CONFIG_DRIVER_WIRED=y`). No need to compile from source for the authenticator role:

```bash
sudo apt install hostapd
```

Verify the wired driver is present:

```bash
strings /usr/sbin/hostapd | grep -i wired
```

## Building from Source (optional)

Only needed if you require features not in the package (e.g. custom EAP-TLS 1.3 flags) or to build `wpa_supplicant`/`eapol_test` on Windows.

https://github.com/openssl/openssl

`git clone https://w1.fi/hostap.git`

```
cd hostap/hostapd
cp defconfig .config
```

Modify the `.config` file to enable the wired driver:

```
# Driver interface for Host AP driver
#CONFIG_DRIVER_HOSTAP=y

# Driver interface for wired authenticator
CONFIG_DRIVER_WIRED=y

# Driver interface for drivers using the nl80211 kernel interface
#CONFIG_DRIVER_NL80211=y
```

### wpa_suplicant

```
sudo apt-get install -y libdbus-1-dev
sudo apt-get install -y libnl-3-dev
sudo apt-get install libnl-genl-3-dev
sudo apt-get install libnl-route-3-dev
```

```
CONFIG_EAP_TLSV1_3=y
CONFIG_TLSV12=y
```
# Authentication Only

#define wpa_dbg wpa_msg

add `#include <in6addr.h>` in `D:\github\hostap\wpa_supplicant\wpa_supplicant_i.h`
Cannot open source file: '..\..\..\src\rsn_supp\peerkey.c': No such file or directory
D:\github\hostap\src\l2_packet\l2_packet_pcap.c

error C2037: left of 'meth' specifies undefined struct/union 'rsa_st'

//#include <net/if.h>
#include <WinSock2.h>

CONFIG_NATIVE_WINDOWS=y
#CONFIG_IPV6=y

`eapol_test.exe -c nanoart.conf -a 192.168.190.13 -p1812 -stesting123`

## Test

`sudo ./hostapd doc/wired.conf -dd`

`./wpa_supplicant -Dwired -iens192 -c./nanoart.conf -dd -K`

# EAP-TLS with Windows 11 VM

Replace or add the Linux supplicant with a Windows 11 VM presenting a client certificate over EAP-TLS. The hostapd wired authenticator and RADIUS server remain unchanged.

## Updated Lab

| Machine | Roles |
| ----    | ----  |
| 192.168.190.62 (Ubuntu 22.04.4) | Access Point hostapd (wired authenticator) |
| 192.168.190.37 (Ubuntu 22.04.4) | RADIUS server (FreeRADIUS) |
| 192.168.190.50 (Windows 11 VM)  | Supplicant — presents client certificate via EAP-TLS |

Connect the Windows 11 VM's NIC to the same switch/bridge as hostapd's authenticator interface (`ens192` on .62).

## Certificate Generation

Run on the RADIUS server (192.168.190.37). The CA signs both the RADIUS server certificate and the client certificate.

```bash
mkdir -p ~/eaptls-ca && cd ~/eaptls-ca

# CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
    -subj "/CN=EAP-TLS Lab CA" -out ca.crt

# RADIUS server certificate
openssl genrsa -out server.key 2048
openssl req -new -key server.key \
    -subj "/CN=radius.lab" -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -days 825 -sha256 \
    -extfile <(printf "subjectAltName=DNS:radius.lab\nextendedKeyUsage=serverAuth") \
    -out server.crt

# Client certificate for Windows 11 VM
openssl genrsa -out client.key 2048
openssl req -new -key client.key \
    -subj "/CN=win11-client" -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -days 825 -sha256 \
    -extfile <(printf "extendedKeyUsage=clientAuth") \
    -out client.crt

# Bundle into PFX for Windows import (set a passphrase)
openssl pkcs12 -export -out client.pfx \
    -inkey client.key -in client.crt -certfile ca.crt \
    -passout pass:YourPfxPassword
```

Copy `ca.crt` and `client.pfx` to the Windows 11 VM (e.g. via shared folder or SCP).

## FreeRADIUS EAP-TLS Configuration

In `/etc/freeradius/3.0/mods-enabled/eap` (or `mods-available/eap`), add or modify the `tls` section inside `eap {}`:

```
eap {
    default_eap_type = tls

    tls-config tls-common {
        private_key_file     = /home/user/eaptls-ca/server.key
        certificate_file     = /home/user/eaptls-ca/server.crt
        ca_file              = /home/user/eaptls-ca/ca.crt
        ca_path              = ${cadir}
        dh_file              = ${certdir}/dh
        cipher_list          = "DEFAULT"
        tls_min_version      = "1.2"
    }

    tls {
        tls = tls-common
    }
}
```

In `/etc/freeradius/3.0/users`, ensure the client CN is authorised:

```
win11-client    Cleartext-Password := "unused"
```

Restart FreeRADIUS:

```bash
sudo systemctl restart freeradius
sudo freeradius -X   # foreground debug to watch EAP-TLS handshake
```

## Windows 11 Setup

### 1. Import Certificates

Open PowerShell as Administrator:

```powershell
# Import CA into Trusted Root CAs (machine store — required for server cert validation)
Import-Certificate -FilePath "C:\certs\ca.crt" `
    -CertStoreLocation Cert:\LocalMachine\Root

# Import client certificate + private key into Personal store
$pfxPwd = ConvertTo-SecureString "YourPfxPassword" -AsPlainText -Force
Import-PfxCertificate -FilePath "C:\certs\client.pfx" `
    -CertStoreLocation Cert:\CurrentUser\My `
    -Password $pfxPwd
```

Verify the client cert is present:

```powershell
Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*win11-client*" }
```

### 2. Enable Wired AutoConfig Service

```powershell
Set-Service -Name dot3svc -StartupType Automatic
Start-Service dot3svc
```

### 3. Apply 802.1X Profile

Save the following as `eap-tls.xml`, replacing `YOUR-ADAPTER-GUID` if needed:

```xml
<?xml version="1.0"?>
<LANProfile xmlns="http://www.microsoft.com/networking/LAN/profile/v1">
    <MSM>
        <security>
            <OneXEnforced>false</OneXEnforced>
            <OneXEnabled>true</OneXEnabled>
            <OneX xmlns="http://www.microsoft.com/networking/OneX/v1">
                <authMode>user</authMode>
                <EAPConfig>
                    <EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
                        <EapMethod>
                            <Type xmlns="http://www.microsoft.com/provisioning/EapCommon">13</Type>
                            <VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId>
                            <VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType>
                            <AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</AuthorId>
                        </EapMethod>
                        <Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
                            <Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1">
                                <Type>13</Type>
                                <EapType xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV1">
                                    <CredentialsSource>
                                        <CertificateStore>
                                            <SimpleCertSelection>true</SimpleCertSelection>
                                        </CertificateStore>
                                    </CredentialsSource>
                                    <ServerValidation>
                                        <DisableUserPromptForServerValidation>true</DisableUserPromptForServerValidation>
                                        <ServerNames>radius.lab</ServerNames>
                                        <TrustedRootCA><!-- SHA-1 thumbprint of ca.crt, no spaces --></TrustedRootCA>
                                    </ServerValidation>
                                    <DifferentUsername>false</DifferentUsername>
                                    <PerformServerValidation xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">true</PerformServerValidation>
                                    <AcceptServerName xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">true</AcceptServerName>
                                </EapType>
                            </Eap>
                        </Config>
                    </EapHostConfig>
                </EAPConfig>
            </OneX>
        </security>
    </MSM>
</LANProfile>
```

Get the CA thumbprint to paste into `<TrustedRootCA>`:

```powershell
(Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*EAP-TLS Lab CA*" }).Thumbprint
```

Apply the profile and trigger authentication:

```powershell
netsh lan add profile filename="eap-tls.xml" interface="Ethernet"
netsh lan set autoconfig enabled=yes interface="Ethernet"
netsh lan connect interface="Ethernet"
```

### 4. Verify

```powershell
# Check 802.1X state
netsh lan show interfaces

# Event log for 802.1X outcomes
Get-WinEvent -LogName "Microsoft-Windows-Wired-AutoConfig/Operational" -MaxEvents 20 |
    Select-Object TimeCreated, Id, Message | Format-List
```

On the RADIUS server, the `freeradius -X` output should show the full TLS handshake and `Access-Accept`.

# References
[eapol_test FreeRADIUS](https://openwrt.org/docs/guide-user/network/wifi/freeradius)
[Testing RADIUS from CLI](https://www.securityccie.net/2023/02/04/testing-radius-from-cli/)
[Testing with eapol_test](https://wiki.geant.org/display/H2eduroam/Testing+with+eapol_test)
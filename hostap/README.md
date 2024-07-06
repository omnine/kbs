# Virtual Access Point - Wired EAP Lab
In order to test RADIUS authentication with EAP-PEAP, generally a physical WIFI access point is needed.
## Lab

| Machine | Roles |
| ----    | ----  |
| 192.168.190.62 (Ubuntu 22.04.4) | Access Point hostapd (the wired authenticator) |
| 192.168.190.37 (Ubuntu 22.04.4) | Supplicant wpa_supplicant, radius |

## OpenSSL

https://github.com/openssl/openssl


`git clone https://w1.fi/hostap.git`

```
cd hostap/hostapd
cp defconfig .config
```

Modify the `.config` file,

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

`sudo ./hostapd wired.conf -dd`

`./wpa_supplicant -Dwired -iens192 -c./nanoart.conf -dd -K`

# References
[eapol_test FreeRADIUS](https://openwrt.org/docs/guide-user/network/wifi/freeradius)
[Testing RADIUS from CLI](https://www.securityccie.net/2023/02/04/testing-radius-from-cli/)
[Testing with eapol_test](https://wiki.geant.org/display/H2eduroam/Testing+with+eapol_test)
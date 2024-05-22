# Virtual Access Point - Wired EAP Lab
In order to test RADIUS authentication with EAP-PEAP, generally a physical WIFI access point is needed.
## Lab

| Machine | Roles |
| ----    | ----  |
| 192.168.190.62 (centos 8) | Access Point hostapd (the wired authenticator) |
| 192.168.190.37 (centos 8) | Supplicant wpa_supplicant, radius |

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

## Test

`./hostapd wired.conf -dd`

`./wpa_supplicant -Dwired -iens192 -c./nanoart.conf -dd -K`
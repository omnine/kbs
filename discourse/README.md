# Discourse installation

[Discourse](https://github.com/discourse/discourse) officially supports only Docker-based installation, which is relatively straightforward—provided your environment meets the expected conditions.

In my case, the setup was a bit different. I had HAProxy running on my router at 192.168.4.1, managing a single public IP shared across multiple domains (virtual hosts). Discourse was installed on an Ubuntu server (192.168.4.5) using Docker.

Knowing that the default setup wouldn’t work with Let’s Encrypt and port 443 due to my network architecture, I still expected HTTP access to function—assuming my local DNS resolved `forum.mydomain.com` to 192.168.4.5. The installation completed without any issues, but both `telnet` and `curl` tests failed.

I found the following articles helpful:

- [How to install Discourse alongside Virtualmin](https://forum.virtualmin.com/t/how-to-install-discourse-alongside-virtualmin/124531)
- [Run other websites on the same machine as Discourse](https://meta.discourse.org/t/run-other-websites-on-the-same-machine-as-discourse/17247)

I initially tried exposing port 80 in the Docker container:

```
expose
  - "80:80"
```

However, the internal Nginx (within the container, configured via `/etc/nginx/conf.d/discourse.conf`) was still set to listen on a Unix domain socket, so that didn’t work.

Instead, I opted not to expose any ports from the container and installed an external Nginx instance. I configured it like this:

```
server {
        listen 80;
        server_name forum.mydomain.com;
        location / {
                proxy_pass http://unix:/var/discourse/shared/standalone/nginx.http.sock:;
                proxy_set_header Host $http_host;
                proxy_http_version 1.1;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Real-IP $remote_addr;
        }
}
            
```

After making this change, both `telnet` and `curl` tests started working.

The next step was configuring HAProxy:

```
backend discourse_backend
    mode http
    option forwardfor
    http-request set-header X-Forwarded-Proto http
    http-request set-header X-Forwarded-Port 443
    http-request set-header Host forum.mydomain.com
    server discourse 192.168.4.5:8080 check

```

With this setup in place, I was finally able to access Discourse via:
https://forum.mydomain.com

# References

[Troubleshoot email on a new Discourse install](https://meta.discourse.org/t/troubleshoot-email-on-a-new-discourse-install/16326)
[Using exchange as SMTP doesn’t work](https://meta.discourse.org/t/using-exchange-as-smtp-doesnt-work/149073)

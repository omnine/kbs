# Discourse installation

Discourse only provides docker installation. It looks simple if the conditions are met.

My environment is different, I had HAProxy installed on the router (192.168.4.1), and using one public IP for multiple website domains(hosts). Discourse was installed on Ubuntu (192.168.4.5) with docker.

With the default installation, I knew letsencrypt certificate and port 443 won't work, but I thought htt should work if LAN DNS resolved `forum.mydomain.com` to `192.168.4.5`.
The installation finished without any error, but telnet and curl failed.

I came across these two articles.
[How to install Discourse alongside Virtualmin](https://forum.virtualmin.com/t/how-to-install-discourse-alongside-virtualmin/124531)
[Run other websites on the same machine as Discourse](https://meta.discourse.org/t/run-other-websites-on-the-same-machine-as-discourse/17247)

I still thought I could do,
```
expose
  - "80:80"
```
Unfortunately the inner nginx (inside container, check the file, `/etc/nginx/conf.d/discourse.conf`) was still listening on the unix domain socket.

OK, let us expose nothing and install an outside nginx, configure it as,

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

Now both telnet and curl test worked.

It's time to config HAProxy

```
backend discourse_backend
    mode http
    option forwardfor
    http-request set-header X-Forwarded-Proto http
    http-request set-header X-Forwarded-Port 443
    http-request set-header Host forum.mydomain.com
    server discourse 192.168.4.5:8080 check

```

Finally I can access it by https://forum.mydomain.com.

# References

[Troubleshoot email on a new Discourse install](https://meta.discourse.org/t/troubleshoot-email-on-a-new-discourse-install/16326)
[Using exchange as SMTP doesn’t work](https://meta.discourse.org/t/using-exchange-as-smtp-doesnt-work/149073)

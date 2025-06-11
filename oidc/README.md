# OpenID Connect

The configuration with OIDC protocol can be very complicated. DualShield provides huge options you can fine grain. On the other end, it looks haunting. Let us look at some basic configurations which may cover most normal applications.

## Redirect URI

This is provided by SP (service provider) which is called RP (relying party) in OIDC world. As an IDP, Dualshield needs the one. For instance,

`https://login.microsoftonline.com/common/federation/externalauthprovider`

## Client ID and Secret
This is as similar as the shared secret used in RADIUS.
You can specify them or use the strong one prompted by Admin Console.
If SP is a Javascript or mobile application, you do not need a client secret.

## Scopes

The scope is kind of a group of claims. OIDC defines a few standard scopes, please check the details at https://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims.

SP can use Scope Values to request the Claims returned from IDP after authentication.


## OIDC Metadata URL
SP expects this Discovery Endpoint from OIDC IDP provider.

## Username Passover
Some SP does something for the login user before passing it over to IDP for further MFA authentication. Entra ID uses `id_token_hint` which is described at https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest. It is possible to use `login_hint` as the alternative. Please check below to see how DualShield extracts the username from `id_token_hint`.

## Flows

The Authorization Code Flow is a most used one. If you want to learn other flows you can take a look of [Authorization Code Flow](https://auth0.com/docs/get-started/authentication-and-authorization-flow#authorization-code-flow).

## Playground

[OpenID Connect Debugger](https://oidcdebugger.com/) is a very good playground for Authorization Code Flow.


## User Extraction

```
POST https://demo.la.deepnetid.com/sso/v1/authc/oauth/connect/authorize HTTP/1.1
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: en-GB,en;q=0.9
Cache-Control: max-age=0
Connection: keep-alive
Content-Length: 3250
Content-Type: application/x-www-form-urlencoded
Host: demo.la.deepnetid.com
Origin: https://login.microsoftonline.com
Referer: https://login.microsoftonline.com/
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: cross-site
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36
sec-ch-ua: "Chromium";v="136", "Google Chrome";v="136", "Not.A/Brand";v="99"
sec-ch-ua-mobile: ?1
sec-ch-ua-platform: "Android"

scope=openid&response_mode=form_post&response_type=id_token&client_id=9f1a1f01760b465b81e48019c994a1cc&redirect_uri=https%3A%2F%2Flogin.microsoftonline.com%2Fcommon%2Ffederation%2Fexternalauthprovider&claims=%7B%22id_token%22%3A%7B%22amr%22%3A%7B%22essential%22%3Atrue%2C%22values%22%3A%5B%22face%22%2C%22fido%22%2C%22fpt%22%2C%22hwk%22%2C%22iris%22%2C%22otp%22%2C%22tel%22%2C%22pop%22%2C%22retina%22%2C%22sc%22%2C%22sms%22%2C%22swk%22%2C%22vbm%22%2C%22bio%22%5D%7D%2C%22acr%22%3A%7B%22essential%22%3Atrue%2C%22values%22%3A%5B%22possessionorinherence%22%5D%7D%7D%7D&nonce=AwABEgEAAAADAOz_BQD0_0jgLuZX4cvewUx4UX6STf_pwpfF5N6_rh6_QXCytA-snXesJP6PhfnmvgE2_Oub5GqVKCQKvULWYdgv4-B13RogAA&id_token_hint=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6IkNOdjBPSTNSd3FsSEZFVm5hb01Bc2hDSDJYRSJ9.eyJhdWQiOiIzZGI1MDRmZi0xZmZjLTQ5NDQtODZmMy0zYTZkNjkzNjU2NmUiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vODVhOGRhZjktMjk5Yy00NjJkLWE1MjctYWNmOTE2ZTgyNjU4L3YyLjAiLCJpYXQiOjE3NDg5NTI4NTcsIm5iZiI6MTc0ODk1Mjg1NywiZXhwIjoxNzQ4OTUzNzU3LCJlbWFpbCI6IjJmYUBsYS5kZWVwbmV0aWQuY29tIiwibmFtZSI6IjJGQSIsIm9pZCI6IjgwYjRjNzZjLWIyODYtNGMzMC04NjViLTE1MWM5ZTVmZmUyZSIsInByZWZlcnJlZF91c2VybmFtZSI6IjJmYUBsYS5kZWVwbmV0aWQuY29tIiwic3ViIjoiLWhHZnRDVmtwbUdKS3VUU3BocEdKTU03dGR4THpzZGVnZ09BTGZNV0FMQSIsInRpZCI6Ijg1YThkYWY5LTI5OWMtNDYyZC1hNTI3LWFjZjkxNmU4MjY1OCIsInV0aSI6IlVQMjI4bjBuUWtHQS02M1VzZmRVQUEiLCJ2ZXIiOiIyLjAifQ.XpowGz2aKdOTcxR9eEy7AmYU20EGtuvOkF6_lKoaSHsfLJRC3VCU2rjcWll8nOrvwzmDeo_Ha3iN6AO1DYoDWgPaMaJCHiJ1u5enbjOclW3cB8e_0daXk_LqmDrlT24KLdflIsU1_bz3f_7es3i8gLNy9vxEFmfULjElRRIywZ-EUODQxBfiZKEzlfYKvpFVaOLHnYbJE3YYPtUm6uOK74kMwvPeaKTLAqv0Bbmr6UP16n0UagBtsHMoyU_H-H-82oGWRKcV9JkyVaEKYNedv9y0cGXz_nTl7AsQdLgajZTfmOInn2lN35z31wcdwXJZOFRVdPtDODJ9fD7TvSNweg&client-request-id=81325af9-fa2f-48d1-98c6-69e08c7c4851&state=rQQIARAAjdQ_jNtUGADw5HK93lUcvVYVYryhQghw4j_PsX1SJZJL7PjOcezEjmMvkeN_eY7_JLZzTiwWmBgqKIihYmDoWDGgiqEqCwsMxwJiQ0KqEEPVAVWIoTCRK2Kv9PSkT_q-9-mTft-7cpmuElW0ir5Vwavo0U0LgAlAaQIhJhMUAYyFIRNA2QhDAYckrIntEtbJDoligECT61cO_jbw92v__NS5-z18fPu9jny__MY0y-bpUa02j5PMDKpmsUycqhWHtRR6EYxqMLKdVe1hufxjufykXL6_ldYJmgYkYBiMplGAgTpWFXGVEHExMEI1MzQdMwYoKhYGFDS-EDk900N21tPaRTfsw56mr3qtqW9wMiEqctYtpn73Il_xUEGZwm6rm4n4EIotjxR9cdotjOCXrau9xjKb4hdXnMDC-XNrz42TcDyP0-zzyqfbvbkT8fZxHEWOlVUv0pwog5aZwTiSknjuJBl00ls9NpLJYKlEOSIxLDHBUpGXuAhagjAbIPOG5Akqho1Zdzw-WfQgvsrHExel2JXIsV4QFEyiMxrBS2t_4VGG3tZmXKvp-xxp5b1A7ad1f0EJMWz0ln7_eEjSRS5kygCZLUZdU1KT5kkWKKnSHTEKzI91pRMDz0ixvK4ElB7wohKptgzh1OM4jM0tojXA-QBPPVOjJcQQyIFW7-mmA9ti39Zxa103JHQiCWDkRh3GwIwTWeyTYTuU4lOekvsmznLYwmziGiOwoQYBYvdkutlsihGW99k6AVKQzG0iltYFQEdFQwGNOmGvusej1rTAhoP5MrfZAYbyY9GOUYoSBA6oTmPtKJo6CMgzup8aDNv2Qiq3pOZkZI_01JJQcVgEbd9tu74_CdLZoKUfj8Oh0VTCs7iZrdgZBU-UuTQQvFwOMZTLu6xCk2fjMdJcyUJQ50GEpRjrtkXTRd3gTHRO2SywVE9tW_7GB5vEEpj2Gx12fNZtW8ngVFa9leCfBg6lLvv9pqLS-v3Kzf9th2Zkek64EbGRveGdb1DHeVqNnKz2oLIfJ54ZweKFlfRR5SaKkhZqMgxSB-4EwUkcR4BDuQjFUHXSJhh3QoHzivAyr9eWqZOMYbjxl8bRiw6HG4wRtA-d0ITB4TyJXRg4v1Vu4K75bmBWbceZbyqhfbGEP26Xn26_trt7UHm9dFh68wZaOdrdvXJQuoieb5fvXdrsNHnp6x-0ykeNbzDjwf7vn5TOL9XYhu2JaKY21ka6ToakeOp40FrP6Kam87OhNSUSLohojZO9W8QRdmenfGdn53xnj2-NxbYCKPzZztaHl8uP9l7yd_jglf3d0vW9vc-uf_Hd3Xu_dr7dLz1_9eO_Hn55--cnf3TOrx60_hvqcOBYywRm66dX32FOZwt9mvBvr23cFc9UbyA5nCewHU_ziIz2OUGOwow3Fifg1lcHpcebc6307Fr5-bU7W_8C0
```

## References

[What is OIDC?](https://www.microsoft.com/en-gb/security/business/security-101/what-is-openid-connect-oidc?ef_id=_k_Cj0KCQjw0qTCBhCmARIsAAj8C4ZpkyaY1eHua-kW1BLmi5-Dgxut2uYJoqlCreeZdRAND8k43T17BrkaAkkmEALw_wcB_k_&OCID=AIDcmmao55x8o7_SEM__k_Cj0KCQjw0qTCBhCmARIsAAj8C4ZpkyaY1eHua-kW1BLmi5-Dgxut2uYJoqlCreeZdRAND8k43T17BrkaAkkmEALw_wcB_k_&gad_source=1&gad_campaignid=21210150911&gbraid=0AAAAADcJh_vYTm2E8BumMbbQFpCEvj_Z_&gclid=Cj0KCQjw0qTCBhCmARIsAAj8C4ZpkyaY1eHua-kW1BLmi5-Dgxut2uYJoqlCreeZdRAND8k43T17BrkaAkkmEALw_wcB)
[Diagrams of All The OpenID Connect Flows](https://darutk.medium.com/diagrams-of-all-the-openid-connect-flows-6968e3990660)
[Authorization Code Flow](https://auth0.com/docs/get-started/authentication-and-authorization-flow#authorization-code-flow)
[OAuth Client Secret Authentication](https://docs.secureauth.com/ciam/en/oauth-client-secret-authentication.html)
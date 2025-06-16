# DualShield OpenID Connect

The configuration with OIDC protocol can be very complicated. DualShield seems to have implemented a fully a  fully comprehensive OIDC, as it provides huge options you can tune. On the other end, it looks a bit haunting. Let us look at some basic configurations which may cover most normal applications.

## Redirect URI

This is provided by SP (service provider) which is called RP (relying party) in OIDC world. As an IDP, Dualshield needs the one. For instance,

`https://login.microsoftonline.com/common/federation/externalauthprovider`

## Client ID and Secret
This is as similar as the shared secret used in RADIUS.
You can specify them or use the strong one prompted by DualShield Admin Console.
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

Let us see something with examples.

- Username Passover

When Entra EAM redirected to IDP, it posted the following values in form fields to `sso/v1/authc/oauth/connect/authorize`

![alt text](image.png)

The username is in the form field `id_token_hint`,

![alt text](image-1.png)

For Entra EAM, DualShield use `oid`. Please read [Create a SSO service provider in DualShield for EAM integration](https://wiki.deepnetsecurity.com/display/DualShield6/Create+a+SSO+service+provider+in+DualShield+for+EAM+integration) for how the username is extracted. 

>The immutable identifier for an object (`oid`) in the Microsoft identity system, in this case, a user account. This ID uniquely identifies the user across applications - two different applications signing in the same user will receive the same value in the oid claim. The Microsoft Graph will return this ID as the id property for a given user account. Because the oid allows multiple apps to correlate users, the profile scope is required in order to receive this claim. Note that if a single user exists in multiple tenants, the user will contain a different object ID in each tenant - they are considered different accounts, even though the user logs into each account with the same credentials.

- Discovery Endpoint
A proper OIDC provider should provide a Discovery URL.
DualShield, `/sso/v1/authc/oauth/.well-known/openid-configuration`. If you access it with a browser you should get a json result.

The json contains a few important values like `issuer`, `authorization_endpoint`, `token_endpoint`.

[OpenID Connect Debugger](https://oidcdebugger.com/) is a very good playground for Authorization Code Flow. it required `authorization_endpoint`.

![alt text](image-2.png)

In this screenshot, we also see Redirect URI, Client ID, Scope etc.


## References

[What is OIDC?](https://www.microsoft.com/en-gb/security/business/security-101/what-is-openid-connect-oidc?ef_id=_k_Cj0KCQjw0qTCBhCmARIsAAj8C4ZpkyaY1eHua-kW1BLmi5-Dgxut2uYJoqlCreeZdRAND8k43T17BrkaAkkmEALw_wcB_k_&OCID=AIDcmmao55x8o7_SEM__k_Cj0KCQjw0qTCBhCmARIsAAj8C4ZpkyaY1eHua-kW1BLmi5-Dgxut2uYJoqlCreeZdRAND8k43T17BrkaAkkmEALw_wcB_k_&gad_source=1&gad_campaignid=21210150911&gbraid=0AAAAADcJh_vYTm2E8BumMbbQFpCEvj_Z_&gclid=Cj0KCQjw0qTCBhCmARIsAAj8C4ZpkyaY1eHua-kW1BLmi5-Dgxut2uYJoqlCreeZdRAND8k43T17BrkaAkkmEALw_wcB)
[Diagrams of All The OpenID Connect Flows](https://darutk.medium.com/diagrams-of-all-the-openid-connect-flows-6968e3990660)
[Authorization Code Flow](https://auth0.com/docs/get-started/authentication-and-authorization-flow#authorization-code-flow)
[OAuth Client Secret Authentication](https://docs.secureauth.com/ciam/en/oauth-client-secret-authentication.html)

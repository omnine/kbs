# Exchange OOF issue.

My Colleague told me the OOF (Exchange automatic reply) didn't work. He tested it by sending an email from his personal gmail account to his company email account.

I checked the message tracking logs,

`Get-MessageTrackingLog -Sender user@domain.com -Start "2025-03-10 00:00:00" -End "2025-03-12 23:59:59"`

And found it was blocked by gmail,

```
RecipientStatus         : {[{LED=550-5.7.26 Your email has been blocked because the sender is unauthenticated. 550-5.7.26 Gmail requires all senders to authenticate with either SPF or DKIM. 550-5.7.26  Authentication results:
                          550-5.7.26  DKIM = did not pass 550-5.7.26  SPF [] with ip: [my.exchange.server.ip] = did not pass 550-5.7.26  For instructions on setting up authentication, go to 550 5.7.26
                          https://support.google.com/mail/answer/81126#authentication d9443c01a7336-22410ad7979si202153425ad.403 - gsmtp};{MSG=};{FQDN=gmail-smtp-in.l.google.com};{IP=74.125.142.27};{LRT=12/03/2025 19:50:43}]}
```

I searched Internet and found an exactly same problem discussed at [Automatic Reply emails from our organization's email domains are being refused by GMail](https://support.google.com/mail/thread/287952959/automatic-reply-emails-from-our-organization-s-email-domains-are-being-refused-by-gmail?hl=en).

It provided a solution,

> Once I got a SPF record created for our EHLO domain it resolved the issue.


However I did have EHLO FQDN `mail.mydomain.com` which is `A` record on DNS resolved to `my.exchange.server.ip`.

Tried many things, but I still couldn't figure out a way with SPF, so I decided to have a go on [Exchange DKIM Signer](https://github.com/Pro/dkim-exchange).

Fortunately its latest release v3.4.0 (published on Apr 30.2022) works on Exchange 2019 CU15(released Feb 10, 2025).

After adding the DKIM DNS record, the OOF to gmail worked!

I had a chance to check the mail header,

`Received-SPF: none (google.com: postmaster@mail.mydomain.com does not designate permitted sender hosts) client-ip=my.exchange.server.ip;`

Did it imply I need to have a sub domain called `mail.mydomain.com`?

Certainly I can create an account `postmaster@mydomain.com`, but not `postmaster@mail.mydomain.com`.
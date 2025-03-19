# Exchange OOF Issue
My colleague reported that the Exchange automatic reply (OOF) was not working. He tested it by sending an email from his personal Gmail account to his company email address.

Upon checking the message tracking logs with:

`Get-MessageTrackingLog -Sender user@domain.com -Start "2025-03-10 00:00:00" -End "2025-03-12 23:59:59"`

I found that Gmail had blocked the message with the following error:

```
RecipientStatus         : {[{LED=550-5.7.26 Your email has been blocked because the sender is unauthenticated. 
                          550-5.7.26 Gmail requires all senders to authenticate with either SPF or DKIM. 
                          550-5.7.26 Authentication results:
                          550-5.7.26 DKIM = did not pass 
                          550-5.7.26 SPF [] with ip: [my.exchange.server.ip] = did not pass 
                          550-5.7.26 For instructions on setting up authentication, go to 
                          550-5.7.26 https://support.google.com/mail/answer/81126#authentication 
                          550 5.7.26 d9443c01a7336-22410ad7979si202153425ad.403 - gsmtp};{MSG=};{FQDN=gmail-smtp-in.l.google.com};
                          {IP=74.125.142.27};{LRT=12/03/2025 19:50:43}]}
```						  
I came across a discussion on a similar issue: [Automatic Reply emails from our organization's email domains are being refused by Gmail](https://support.google.com/mail/thread/287952959/automatic-reply-emails-from-our-organization-s-email-domains-are-being-refused-by-gmail?hl=en). The suggested solution was:

> "Once I got an SPF record created for our EHLO domain, it resolved the issue."

My EHLO FQDN was already set to `mail.mydomain.com`, and this hostname had an `A` record pointing to `my.exchange.server.ip`. Despite several attempts, I couldn’t get SPF to work correctly.

As an alternative, I decided to try [Exchange DKIM Signer](https://github.com/Pro/dkim-exchange). Fortunately, its latest release (v3.4.0, published on Apr 30, 2022) was compatible with Exchange 2019 CU15 (released on Feb 10, 2025).

After adding the DKIM DNS record, the OOF emails to Gmail started working.

Upon inspecting the mail headers, I noticed:

`Received-SPF: none (google.com: postmaster@mail.mydomain.com does not designate permitted sender hosts) client-ip=my.exchange.server.ip;`

Does this mean I need to create a subdomain `mail.mydomain.com`?

I can create an account `postmaster@mydomain.com`, but not `postmaster@mail.mydomain.com`.  
Still curious if it is possible to solve this problem by just using pure SPF. 
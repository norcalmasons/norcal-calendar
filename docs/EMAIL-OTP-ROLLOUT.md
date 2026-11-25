# NorCal Masons Dev — branded email verification

Apply only to the independent NorCal development project `ltowvwvryodzrxtpattd`. Do not change Division IV.

- Custom SMTP: existing NorCal mailbox (already configured).
- Site URL: https://dev.norcalmasons.org
- Redirect URLs: https://dev.norcalmasons.org/inspectors/ and https://dev.norcalmasons.org/events/
- Magic Link email subject: Verification Code
- Confirm Signup email subject: Sign-Up Verification Code
- Both email bodies: copy the complete HTML from `auth-email-otp-template.html` in this directory. Preserve the literal Supabase token variable. Leave Invite User unchanged.
- Email OTP length: 8; expiration: 600 seconds.

After saving the hosted templates, test a returning administrator login and inspect the email for the new logo, eight-digit code and no sign-in link. Complete MFA before accessing protected actions. A first-time registration test may be performed with an authorized test mailbox. Do not enable public submissions, notifications or calendar synchronization during development.

Dashboard templates are separate hosted settings; committing this file does not change the emails Supabase sends.

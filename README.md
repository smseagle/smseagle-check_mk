# Checkmk SMSEagle Notification Plugin

Send SMS alerts and notifications from [Checkmk](https://checkmk.com/) via [SMSEagle](https://www.smseagle.eu) hardware SMS gateway.

Bash script for **Checkmk 2.x** using **SMSEagle APIv2**.

### Requirements

- Checkmk 2.x (CEE, CRE, or CME)
- SMSEagle device with firmware supporting APIv2 (v5.0+)
- `curl` available on the Checkmk server

### SMSEagle Setup

1. Log in to the SMSEagle web GUI
2. Go to **Users** menu
3. Create a new user (or use an existing one)
4. Edit **Access to API** for the user - Generate an access token and enable permission for SMS sending
5. Copy the token - you will need it for Checkmk configuration

### Checkmk Installation

```bash
# Switch to your Checkmk site user
su - mysite

# Copy the script to the notifications directory
cp check_mk_smseagle-notify.sh ~/local/share/check_mk/notifications/

# Make it executable
chmod 755 ~/local/share/check_mk/notifications/check_mk_smseagle-notify.sh

# Restart the site
omd restart
```

### Checkmk Configuration

1. Go to **Setup > Events > Notifications**
2. Click **Add rule**
3. Set **Notification Method** to `SMSEagle`
4. Fill in the parameters:

| Parameter | Description | Example                             | Required |
|-----------|-------------|-------------------------------------|----------|
| **Parameter 1** | SMSEagle device URL | `https://192.168.0.100`             | Yes |
| **Parameter 2** | API Access Token | `123abc456def`                      | Yes |
| **Parameter 3** | Verify SSL (`yes`/`no`) | `no` (for self-signed certs)        | No (default: `yes`) |
| **Parameter 4** | SMS priority (0-9) | `5`                                 | No |
| **Parameter 5** | Encoding (`standard`/`unicode`) | `unicode` (for national characters) | No (default: `standard`) |
| **Parameter 6** | Modem number | `2` (for multi-modem devices)       | No |

5. Under **Contact selection**, choose the users or contact groups to notify
6. Make sure each contact has a **Pager** field filled with their phone number (including country code, e.g. `+48123456789`)

### Custom User Attributes (alternative)

Instead of notification rule parameters, you can define per-contact settings using Checkmk Custom User Attributes:

| Attribute Name | Description |
|----------------|-------------|
| `SMSEAGLE_URL` | SMSEagle device URL |
| `SMSEAGLE_TOKEN` | API Access Token |
| `SMSEAGLE_VERIFY_SSL` | Verify SSL (`yes`/`no`) |
| `SMSEAGLE_PRIORITY` | SMS priority (0-9) |
| `SMSEAGLE_ENCODING` | Encoding (`standard`/`unicode`) |
| `SMSEAGLE_MODEM_NO` | Modem number (for multi-modem devices) |

Custom attributes take precedence over notification rule parameters.

### Troubleshooting

Check the notification log for debug output:
```bash
tail -f ~/var/log/notify.log
```

All debug messages are prefixed with `DEBUG:` and errors with `ERROR:`.

---

## Version 1.0 (legacy) - `notify_smseagle.py`

Original Python 2.x script using the legacy SMSEagle HTTP API (`/http_api/send_sms`). Kept for backward compatibility with older Checkmk/SMSEagle installations.
You can find it in the `obsolete` directory.

**Note:** This version requires editing the script directly to set SMSEagle hosts and credentials.

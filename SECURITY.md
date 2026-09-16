# Security Policy

## Security Considerations

Vitals is a macOS system monitor that reads hardware metrics via IOKit and the SMC
interface. It can make one external network request -- fetching the device's public
IP address from `api.ipify.org` over HTTPS -- but this lookup is **opt-in and
disabled by default**. No request leaves the machine unless the user explicitly
enables "Show public IP" in General settings. All collected data is stored locally
in an App Group container, and the shared metrics file is written with owner-only
(600) permissions.

## Data Collected

The following metrics are gathered and stored locally:

- CPU usage and temperature
- GPU usage and temperature
- Memory usage
- Battery health, cycle count, charge state, and temperature
- Disk usage
- Network throughput (upload/download)
- WiFi SSID and local IP address
- Public IP address (single HTTPS request to api.ipify.org, opt-in only)
- Hostname and current username

All data remains on the local machine. The only external communication is the
HTTPS GET request to `https://api.ipify.org` used to resolve the public IP, and it
is made only when the user has turned on the opt-in "Show public IP" setting
(disabled by default).

## Known Limitations

- **Not notarized.** The app is not notarized with Apple because no paid Developer
  account is available. Users must allow the app manually in System Settings.
- **Not sandboxed.** Full App Sandbox is disabled because the app requires direct
  IOKit/SMC access to read hardware sensors.
- **Third-party IP lookup.** The public IP address is obtained from api.ipify.org,
  a third-party service. This lookup is opt-in and disabled by default; when off, no
  request is ever sent. No other data is sent in the request.

## Reporting Vulnerabilities

If you discover a security issue, please open a GitHub issue on the repository.

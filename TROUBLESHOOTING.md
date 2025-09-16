# Troubleshooting for Copilot for Xcode

If you are having trouble with Copilot for Xcode follow these steps to resolve
common issues:

1. Check for updates and restart Xcode. Ensure that XcodePaI has the
   [latest release](https://github.com/so898/XcodePaI/releases/latest/)
   by clicking `Check for Updates` in the settings or under the status menu. After
   updating, restart Xcode.

2. Ensure that all required permissions are granted. XcodePaI app requires these permission to function properly:
   - [Accessibility Permission](#accessibility-permission) - Enables real-time code suggestions

   Please note that XcodePaI may not work properly if any necessary permissions are missing.

3. Need more help? If these steps don't resolve the issue, please [open an
   issue](https://github.com/so898/XcodePaI/issues/new/choose).

## Accessibility Permission

XcodePaI requires the accessibility permission to receive
real-time updates from the active Xcode editor. [The XcodeKit
API](https://developer.apple.com/documentation/xcodekit)
enabled by the Xcode Source Editor extension permission only provides
information when manually triggered by the user. In order to generate
suggestions as you type, the accessibility permission is used to read the
Xcode editor content in real-time.

The accessibility permission is also used to accept suggestions when `tab` is
pressed.

The accessibility permission is __not__ used to read or write to any
applications besides Xcode. There are no granular options for the permission,
but you can audit the usage in this repository: search for `CGEvent` and `AX`*.

Enable in System Settings under `Privacy & Security` > `Accessibility` > 
`XcodePaI` and turn on the toggle.
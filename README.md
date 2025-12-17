# <img align="center" height="70" src="./Docs/Images/AppIcon.png"/> XcodePaI

<div align="center">
  <img src="./Docs/Images/AppIcon.png" width="180" height="180" />
  <h1>XcodePaI</h1>
  <p>The AI pair programmer for Xcode.</p>

  ![GitHub License](https://img.shields.io/github/license/so898/XcodePaI)
  ![Platform](https://img.shields.io/badge/platform-macOS%2026.0%2B-brightgreen)
  [![GitHub release (latest by date)](https://img.shields.io/github/v/release/so898/XcodePaI)](https://github.com/so898/XcodePaI/releases)
  ![GitHub all releases](https://img.shields.io/github/downloads/so898/XcodePaI/total)
  ![GitHub stars](https://img.shields.io/github/stars/so898/XcodePaI?style=social)
  [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/so898/XcodePaI)
</div>

[XcodePaI](https://github.com/so898/XcodePaI)(/ɛksˈkoʊd pæl/) is an AI pair programmer
tool that enchance your Xcode AI function which helps you write code faster and smarter. XcodePaI is an Xcode extension that provides local proxy to enchange Xcode 26 coding assistant and inline coding suggestions as you type.

## ChatProxy

XcodePaI provide local proxy server for Xcode to regconize as local model provider. Multiple model provider with OpenAI API format could be proxy to Xcode coding assistant.

## Agent Mode

XcodePaI enhance Xcode coding assistant with Agent Mode provides AI-powered assistance that can understand and modify your codebase directly. With Agent Mode, you can:
- Get intelligent code edits applied directly to your files
- Search through your codebase to find relevant files and code snippets
- Create new files and directories as needed for your project
- Get assistance with enhanced context awareness across multiple files and folders
- Run Model Context Protocol (MCP) tools you configured to extend the capabilities

Agent Mode integrates with Xcode coding assistant's environment, creating a seamless development experience where assistant can help implement features, fix bugs, and refactor code with comprehensive understanding of your project inside Xcode.

## Code Completion

You can receive auto-complete type suggestions from any available model provider by starting to write the code you want to use, or by writing a natural language comment describing what you want the code to do.

OpenAI format `v1/completions` and `v1/chat/completions` endpionts with <b>partial</b> supported model could be use as your code suggestion/completion provider.

<img alt="Code Completion of XcodePaI" src="./Docs/Images/code-completions.gif" width="800" />

## Requirements

- macOS 15+
- Xcode 16+

## Getting Started

1. download the `zip` from
   [the latest release](https://github.com/so898/XcodePaI/releases/latest/).
   Unzip zip file, drag `XcodePaI.app` into the `Applications` folder.

1. Open the `XcodePaI` application (from the `Applications` folder). Accept the security warning.
   <p align="center">
     <img alt="Screenshot of MacOS download permission request" src="./Docs/Images/macos-download-open-confirm.png" width="350" />
   </p>

1. Open `XcodePaI` Settings -> Provider to add Model Provider.
   <p align="center">
    <img alt="Screenshot of XcodePaI add model provider" src="./Docs/Images/settings-add-model-provider.png" width="648" />
   </p>

   XcodePaI accept model provider such as Ollama/Alibaba Cloud/OpenRouter and other provider support OpenAI `v1` endpoint format.

1. Open model provider detail to sync models from service

1. *[Opiontal]* Open `XcodePaI` Settings -> MCP to add MCP service

   <p align="center">
    <img alt="Screenshot of XcodePaI add MCP" src="./Docs/Images/settings-add-mcp.png" width="648" />
   </p>

1. *[Opiontal]* Create custom model config

   <p align="center">
    <img alt="Screenshot of XcodePaI add model config" src="./Docs/Images/settings-add-model-config.png" width="648" />
   </p>

## How to use ChatProxy

   Open Intelligent in Xcode configuration window.
  - Open via the Xcode menu `Xcode -> Settings -> Intelligent`.
  <p align="center">
    <img alt="Screenshot of Xcode settings intelligent" src="./Docs/Images/xcode-settings-intelligent.png" width="648" />
  </p>

  - Add XcodePaI as Local Model Provider

  <p align="center">
    <img alt="Screenshot of Xcode Settings intelligent add lcoal provider" src="./Docs/Images/xcode-settings-intelligent-add.png" width="648" />
  </p>

  - Check XcodePaI local model provider info

  <p align="center">
    <img alt="Screenshot of Xcode local provider info" src="./Docs/Images/xcode-settings-intelligent-add-info.png" width="648" />
  </p>


  - Create new chat via Xcode Code Assistant sidebar, and choose XcodePaI as the model provider.

  <p align="center">
    <img alt="Screenshot of xocde assistant sidebar" src="./Docs/Images/xcode-code-assistant-sidebar.png" width="244" />
  </p>

  - Via statusbar button menu, the model used in code assistant chat window could be change

  <p align="center">
    <img alt="Screenshot of change chat model" src="./Docs/Images/statusbar-menu-change-chat-model.png" width="244" />
  </p>

## How to use Code Completion

Two permissions are required for XcodePaI to function code completions properly: `Accessibility`, and `Xcode Source Editor Extension`. For more details on why these permissions are required see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

1. __The `Accessibility` permission__ can be requested via XcodePaI Settings -> Completions -> Accesibility Permission:

   <p align="center">
     <img alt="Screenshot of XcodePaI accessibility permission request" src="./Docs/Images/accessibility-permission-settings.png" width="529" />
   </p>

   Via Grant Permission button, XcodePaI will open permission request window for Accessibility permission.

   <p align="center">
     <img alt="Screenshot of accessibility permission request" src="./Docs/Images/accessibility-permission-request.png" width="370" />
   </p>

   The Accessibility permission could be granted in the System Preferences:

   <p align="center">
     <img alt="Screenshot of System accessibility permission request" src="./Docs/Images/accessibility-permission-system-preferences.png" width="529" />
   </p>

1. __The `Xcode Source Editor Extension` permission__ needs to be enabled manually. Click
   `Extension Permission` from the `XcodePaI` application completions settings to open the
   System Preferences to the `Extensions` panel. Select `Xcode Source Editor`
   and enable `XcodePaI`:

   <p align="center">
     <img alt="Screenshot of extension permission" src="./Docs/Images/extension-permission.png" width="529" />
   </p>

1. After granting the extension permission, open Xcode. Verify that the
   `XcodePaI` menu is available and enabled under the Xcode `Editor`
   menu.
    <br>
    <p align="center">
      <img alt="Screenshot of Xcode Editor menu item" src="./Docs/Images/xcode-editor-menu.png" width="370" />
    </p>

    Keyboard shortcuts can be set for all menu items in the `Key Bindings`
    section of Xcode preferences.

1. To enable `Xcode Source Editor Extension`, click `Sync Text Settings` in the menu.

    <br>
    <p align="center">
      <img alt="Screenshot of Xcode Editor Extension permission" src="./Docs/Images/extension-local-folder-permission.png" width="370" />
    </p>

    Please grant any access permission for XcodePaI and XcodePaI Xcode Extension.

1. To avoid confusion, we recommend disabling `Predictive code completion` under
   `Xcode` > `Preferences` > `Text Editing` > `Editing`.

1. Press `tab` to accept the first line of a suggestion, hold `option` to view
   the full suggestion, and press `option` + `tab` to accept the full suggestion.

   Press `tab` to accept the first line of a suggestion, hold `option` to view
   the full suggestion, and press `option` + `tab` to accept the full suggestion.

## License

This project is licensed under the terms of the MIT open source license. Please
refer to [LICENSE.txt](./LICENSE.txt) for the full terms.

## Acknowledgements

Thank you to @intitni and @Github for creating the code completions method for Xcode that this project is based on.

Attributions can be found under About when running the app or in
[Credits.rtf](./Docs/Credits.rtf).
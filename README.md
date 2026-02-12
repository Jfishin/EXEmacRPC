# EXEmacRPC

EXEmacRPC is a lightweight macOS menu bar application that automatically detects running games and updates your Discord Rich Presence status. It's particularly useful for games running through Wine, CrossOver, or other translation layers that might not natively support Discord integration on macOS.

## Features

- **Automatic Game Detection**: Periodically scans running processes to identify active games.
- **Discord Rich Presence**: Automatically updates your Discord status with the game you're playing, including the time elapsed.
- **Dynamic Cover Art**: Fetches high-quality game covers from the IGDB (Internet Game Database) for a polished Discord profile.
- **Customizable**:
  - **Blacklist**: Exclude specific processes from being detected as games.
  - **Overrides**: Manually map process names to more descriptive game titles (e.g., mapping `d2` to `Diablo II`).
- **Menu Bar Integration**: Easily enable/disable the monitor and access configuration directly from the macOS menu bar.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/EXEmacRPC.git
   ```
2. Open `EXEmacRPC.xcodeproj` in Xcode.
3. Build and run the project.

## Configuration

The application stores its configuration in a JSON file located at:
`~/Library/Application Support/EXEmacRPC/config.json`

You can manually edit this file to manage your blacklist and overrides, or use the configuration window within the app.

### Example Config Structure
```json
{
  "blacklist": ["steam", "wineboot", "services"],
  "overrides": {
    "d2": "Diablo II",
    "hl2": "Half Life 2"
  }
}
```

## How it Works

- **ProcessScanner**: Identifies running processes and attempts to filter out system utilities to find the actual game.
- **IGDBClient**: Queries the IGDB API to find the correct game title and cover image.
- **DiscordIPCClient**: Communicates with the Discord desktop client via local IPC to set the Rich Presence activity.

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for building)
- Discord desktop app running locally

## License

[MIT License](LICENSE) 

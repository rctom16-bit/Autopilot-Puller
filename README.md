# Windows Autopilot-Puller
**rctom16-bit** - Feb 2026


## Features
- Automatic file name function (serial number) or manual name
- Automatically converts the file to a .csv
- Easy to understand and use
- Fallback in case of no USB stick -> C:\Windows\Temp
- Optional: Direct upload to Intune via app registration (no manual import needed)

## Usage

1. Use Autopilot-Puller Start as Administrator
2. Let the tool run and accept the NuGet for the save-script funktion
3. Select output mode: Save to USB or Upload to Intune (if config.json is present)
4. Enter file name or leave empty for Serial Number
5. Finished, file will get exported or uploaded automatically

## Windows Install
You can use the script in the setup screen, by pressing Shift + F10, switch to the USB drive with cd and then just run the .bat

## Direct Intune Upload (Optional)

To enable silent, automatic upload to Intune without logging in manually, you need to set up an Azure App Registration:

### 1. Create an App Registration
1. Go to [portal.azure.com](https://portal.azure.com) → **Entra ID** → **App registrations** → **New registration**
2. Name it something like `AutopilotImporter`, keep it single tenant, no redirect URI needed
3. Click **Register**

### 2. Grant API Permissions
1. Open your new app → **API permissions** → **Add a permission**
2. Choose **Microsoft Graph** → **Application permissions**
3. Search for and add: `DeviceManagementServiceConfig.ReadWrite.All`
4. Click **Grant admin consent** (requires Global Admin or Intune Admin)

### 3. Create a Client Secret
1. Go to **Certificates & secrets** → **New client secret**
2. Set an expiry and click Add
3. **Copy the secret value immediately** — you won't see it again

### 4. Configure config.json
1. Copy `config.example.json` and rename it to `config.json`
2. Fill in your values:

```json
{
  "TenantId": "your-tenant-id",
  "ClientId": "your-client-id",
  "ClientSecret": "your-client-secret"
}
```

3. Place `config.json` next to the script on your USB drive
4. The script will detect it automatically and offer the upload option on next run

> **Note:** `config.json` is excluded from Git via `.gitignore` — your credentials will never be pushed to GitHub.



Hi there,

this is my first little script. It might be not much but I hate entering these 4 lines in PowerShell to get my Autopilot-Info and mostly I forget the .csv at the end of the file

This script will do all that automatically, you just have to click Y for one NuGet provided, this is normal for Microsoft Scripts

You can Name the file or leave the name empty, in this case the script will read out the Serial Number of the laptop and name the file like that

The script will automatically detect if you have a USB drive inserted and will chose it as the main export

Hope you enjoy the script



rctom16-bit

# Create Desktop Shortcut for an Application on Ubuntu

This document explains how to create a **desktop/application menu shortcut** for an AppImage-based application on Ubuntu Linux.

The example used here is **Requestly AppImage**, but the same steps apply to **any AppImage application**.

### Step 1: Move the AppImage to a Standard Location

It is recommended to store AppImages in `/opt` for system-wide applications.

```bash
sudo mv Requestly-1.6.0.AppImage /opt/requestly.AppImage
```

### Step 2: Make the AppImage Executable

Ensure the AppImage has execute permissions:

```bash
sudo chmod +x /opt/requestly.AppImage
```

### Step 3: Create a Desktop Entry File

Desktop shortcuts in Linux are defined using `.desktop` files.

Create a new desktop entry:

```bash
nano ~/.local/share/applications/requestly.desktop
```

### Step 4: Add Desktop Entry Configuration

Paste the following content into the file:

```ini
[Desktop Entry]
Name=Requestly
Comment=HTTP Request Interceptor & Debugger
Exec=/opt/requestly.AppImage
Icon=requestly
Terminal=false
Type=Application
Categories=Development;Network;
```

Save and exit

#### Field Explanation

| Field | Description |
|------|------------|
| Name | Application name shown in menu |
| Comment | Short description |
| Exec | Full path to AppImage |
| Icon | Icon name or full icon path |
| Terminal | Run in terminal or not |
| Type | Application type |
| Categories | Menu classification |

### Step 5: (Optional) Add Application Icon

If the icon does not appear, download an icon file (PNG/SVG) and place it in:

```bash
~/.local/share/icons/
```

Example:

```bash
cp requestly.png ~/.local/share/icons/requestly.png
```

Then update the desktop file:

```ini
Icon=/home/<username>/.local/share/icons/requestly.png
```

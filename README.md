# UMT-Install-Script
A script to easily install [UndertaleModTool](https://github.com/UnderminersTeam/UndertaleModTool) on Linux using Wine.
## Usage
**Download**, **make executable**, and **run** the script:

1) Clone the repo, go into its content
```bash
git clone https://github.com/xeaft/UMT-Install-Script
cd UMT-Install-Script
```
*OR* simply fetch it
```bash
curl -O https://raw.githubusercontent.com/xeaft/UMT-Install-Script/main/install.sh
```
2) Then make it executable
```bash
chmod +x install.sh
```
3) Run the script
```bash
./install.sh
```
*Alternatively*, you can directly fetch & execute it:
```bash
curl -o- "https://raw.githubusercontent.com/xeaft/UMT-Install-Script/refs/heads/main/install.sh" | bash -s --
```

## Dependencies:
- `curl`
- `unzip`
- `winetricks`
- `wine`

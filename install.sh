#!/bin/bash




UMT_Path="${HOME}/UndertaleModTool"
export WINEPREFIX="${UMT_Path}/pfx"

readonly GREEN="\033[32m"
readonly RED="\033[91m"
readonly YELLOW="\033[0;33m"
readonly CLEAR="\033[0m"

readonly EXIT_SUCCESS=0
readonly UNKNOWN_ARGUMENT=1
readonly CURL_DOWNLOAD_FAILED=2
readonly UNSATISFIED_DEPENDENCY=3
readonly UMT_NOT_ACCESSIBLE=4
readonly RAN_AS_ROOT=5

readonly DEPENDENCIES=("unzip" "curl" "wine" "winetricks")

applyDarkMode=0
fetchFromGit=1
update=0
desktopShortcut=0
showHelp=0
uninstall=0

if [ "$EUID" -eq 0 ]; then
  printf "${RED}Do not run as root.${CLEAR}\n"
  exit "${RAN_AS_ROOT}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--update) update=1 ;;
    -d|--dark-mode) applyDarkMode=1 ;;
    -l|--local) fetchFromGit=0 ;;
    -h|--help) showHelp=1 ;;
	-s|--desktop-shortcut) desktopShortcut=1 ;;
	--uninstall) uninstall=1 ;;
    *) printf "${RED}Unknown arugment: $1${CLEAR}\n" >&2; exit "${UNKNOWN_ARGUMENT}" ;;
  esac
  shift
done

if [ "${showHelp}" -eq 1 ]; then
	printf "Usage: ./install [flags]\n"
	printf "\nflags:\n"
	
	printf "\t-u, --update\t\t\tUpdates the current install of UndertaleModTool. Doesn't support -l.\n"
	printf "\t-d, --dark-mode\t\t\tChanges UndertaleModTool to dark mode (if it has ever been launched) and exits.\n"
	printf "\t-l, --local\t\t\tInstalls UndertaleModTool from an existing local copy. Must be ran within its dir.\n"
	printf "\t-s, --desktop-shortcut\t\tCreates a desktop shortcut for UndertaleModTool.\n"
	printf "\t--uninstall\t\t\tUninstalls UndertaleModTool.\n"
	printf "\n\t-h, --help\t\t\tShows this page.\n"
	
	printf "\nDependiencies\n"
	for dep in "${DEPENDENCIES[@]}"; do
		printf "\t${dep}\n"
	done

	exit "${EXIT_SUCCESS}"
fi

if [ "${applyDarkMode}" -eq 1 ]; then
	running=0
	stillRunning=0
	pgrep UndertaleMod >/dev/null && running=1

	if [ "${running}" -eq 1 ]; then
		printf "${YELLOW}UndertaleModTool is currently running. To proceed, it has to be killed or closed.\n"
		printf "If you decide to continue without saving your work, it will be lost. Continue? [n/Y]${CLEAR} "

		read -r answer < /dev/tty
		answer=${answer:-N}

		if [[ "$answer" =~ ^[Yy]$ ]]; then
			stillRunning=0
			pgrep UndertaleMod >/dev/null && stillRunning=1
			if [ "${stillRunning}" -eq 1 ]; then killall UndertaleModTool.exe; fi
		else
			printf "Ok. exiting.\n"
			exit "${EXIT_SUCCESS}"
		fi
	fi	

	umtSettingsPath="${UMT_Path}/pfx/drive_c/users/${USER}/AppData/Roaming/UndertaleModTool"
	if [ ! -d "${umtSettingsPath}" ]; then
		printf "${RED}You must run UndertaleModTool at least once before changing it's settings!${CLEAR}\n"
		exit "${UMT_NOT_ACCESSIBLE}"
	fi
	jq '.EnableDarkMode = true' "${umtSettingsPath}/settings.json" > "${umtSettingsPath}/tmpSettings.json"
	mv "${umtSettingsPath}/tmpSettings.json" "${umtSettingsPath}/settings.json"
	printf "${GREEN}Set UndertaleModTool to dark mode.${CLEAR}\n"

	if [ "${stillRunning}" -eq 1 ]; then
		wine "${UMT_Path}/UndertaleModTool.exe"
	fi

	exit "${EXIT_SUCCESS}"
fi

checkInstalled() {
	if command -v "$1" >/dev/null 2>&1; then
		return 0
	fi
	return 1
}

checkDependencies() {
	missingDeps=()
	for dep in "${DEPENDENCIES[@]}"; do
		if ! checkInstalled "${dep}"; then
			missingDeps+=("${dep}")
		fi
	done
	
	missingDepCount="${#missingDeps[@]}"
	if [ "${missingDepCount}" -gt 0 ]; then
		printf "${RED}Missing dependencies:${CLEAR} "
		if [ "${missingDepCount}" -eq 1 ]; then
			printf "${missingDeps[0]}\n"
		else
			for ((i=0; i < missingDepCount-1; i++)); do
				printf "${missingDeps[${i}]}, "
			done
		
			missingDepCount=$(( missingDepCount - 1 ))
			printf "${missingDeps[${missingDepCount}]}\n"
		fi

		exit "${UNSATISFIED_DEPENDENCY}"
	fi
}
checkDependencies

if [ "${fetchFromGit}" -eq 0 ] && [ "${update}" -eq 0 ]; then
	UMT_Path=$(dirname "$(readlink -f "$0")")
fi

if [ "${uninstall}" -eq 1 ]; then
	rm  -r "${UMT_Path}"
	rm "${HOME}/.local/share/applications/UndertaleModTool.desktop"
	printf "${GREEN}Uninstalled UndertaleModTool.\n"
	exit "${EXIT_SUCCESS}"
fi

if [ "${update}" -eq 1 ]; then 
	if [ "${fetchFromGit}" -eq 0 ]; then
		printf "-u is present, ignoring -l\n"
		fetchFromGit=1
	fi
		if [ "${applyDarkMode}" -eq 0 ]; then
		printf "-u is present, ignoring -lm\n"
	fi
fi

if [ -d "${UMT_Path}" ] && [ "${update}" -eq 0 ]; then
	printf "UndertaleModTool seems to already be installed.\n"
	printf "If you only want to update your existing install, use -u (or --update).\n"
	printf "Do you want to re-install UndertaleModTool? [y/N] "

	read -r answer < /dev/tty
	answer=${answer:-N}

    if [[ "$answer" =~ ^[Yy]$ ]]; then
		printf "${YELLOW}Removing old UndertaleModTool instance${CLEAR}\n"
		rm -r "${UMT_Path}"
		mkdir "${UMT_Path}"
    else
		printf "Ok. exiting.\n"
        exit "${EXIT_SUCCESS}"
    fi
else
	mkdir "${UMT_Path}"
fi

createWinePref() {
	wine wineboot
	winetricks arial
}

downloadFromGithub() {
	printf "${YELLOW}Downloading UndertaleModTool from GitHub...${CLEAR}\n"
	json=$(curl -s "https://api.github.com/repos/UnderminersTeam/UndertaleModTool/releases/latest")
	tag=$(echo "$json" | jq -r '.tag_name')
	filename="UndertaleModTool_v${tag}-Windows-SingleFile.zip"
	url=$(echo "$json" | jq -r --arg name "$filename" '.assets[] | select(.name == $name) | .browser_download_url')

	dest="${UMT_Path}/UMT_Release.zip"
	folPath="${UMT_Path}"
	if [ "${update}" -eq 1 ]; then
		if [ ! -d "${UMT_Path}/tmp" ]; then
			mkdir "${UMT_Path}/tmp"
		fi
		folPath="${UMT_Path}/tmp/umt"
		mkdir "${folPath}"
		dest="${folPath}/UMT_Release.zip"
	fi

	curl -L -o "${dest}" "$url"
	if [ $? -ne 0 ]; then
		printf "${RED}Failed to download latest UndertaleModTool release${CLEAR}\n"
		exit "${CURL_DOWNLOAD_FAILED}"
	fi
	printf "${GREEN}Downloaded UndertaleModTool release${CLEAR}\n"

	( cd "${folPath}"; unzip "${dest}" && rm "${dest}" )
}

removeForUpdate() { # "why no use UMT's Updater?" - because wine.
	rm "${UMT_Path}/UndertaleModTool.exe"
	rm "${UMT_Path}/Underanalyzer.pdb"
}

moveToUpdate() {
	mv "${UMT_Path}/tmp/umt/UndertaleModTool.exe" "${UMT_Path}/UndertaleModTool.exe"
	mv "${UMT_Path}/tmp/umt/Underanalyzer.pdb" "${UMT_Path}/Underanalyzer.pdb"
	rsync -a "${UMT_Path}/tmp/umt/GameSpecificData/" "${UMT_Path}/GameSpecificData/"
	rsync -a "${UMT_Path}/tmp/umt/Corrections/" "${UMT_Path}/Corrections/"
	rsync -a "${UMT_Path}/tmp/umt/Scripts/" "${UMT_Path}/Scripts/"

	rm -rf "${UMT_Path}/tmp/umt"
}

installWinRuntime() {
	printf "\n\n\n${YELLOW}Downloading Windows Desktop Runtime...${CLEAR}\n"
	if [ ! -d "${UMT_Path}/tmp" ]; then
		mkdir "${UMT_Path}/tmp"
	fi
	winRtPath="${UMT_Path}/tmp/windesktop_runtime.exe"
	curl --fail -L -o "${winRtPath}" "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.18/windowsdesktop-runtime-8.0.18-win-x64.exe"

	if [ $? -ne 0 ]; then
		printf "${RED}Failed to download Windows Desktop Runtime.${CLEAR}\n"
		exit "${CURL_DOWNLOAD_FAILED}"
	fi

	printf "\n\n${YELLOW}Installing Windoes Desktop Runtime...${CLEAR}\n"
	wine "${winRtPath}" /install /quiet /norestart
	rm "${winRtPath}"
	printf "\n\n${GREEN}Installed WinDesktop Runtime${CLEAR}\n"
}

promptInstallMsg() {
	printf "${RED}You don't have wine-mono installed${CLEAR}, do you want to install it with $1 (system-wide)?\n"
	printf "${RED}wine-mono is necessary${CLEAR} for UndertaleModTool to run, but you will be prompted\n"
	printf "(by wine) to install it only to the prefix when running UndertaleModTool for the first time\n"
	printf "${GREEN}Install wine-mono? [Y/n]: ${CLEAR}"

	read -r answer < /dev/tty
	answer=${answer:-Y}

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

ensureWineMono() {
	manager=""
	pkg="wine-mono"
	installed=0

	if which pacman >/dev/null 2>&1; then
		manager="pacman"
		if pacman -Q "$pkg" >/dev/null 2>&1; then installed=1; fi
	elif which dnf >/dev/null 2>&1; then
	    manager="dnf"
		if dnf list installed "$pkg" >/dev/null 2>&1; then installed=1; fi
	elif which apt >/dev/null 2>&1; then
		manager="apt"
	    if dpkg -s "$pkg" >/dev/null 2>&1; then installed=1; fi
	fi

	if [ -z "$manager" ]; then 
		printf "${YELLOW}warn: Couldn't detect your systems package manager. It's recommended you\n"
		printf "have the wine-mono package for your system. If not, wine will prompt you to install\n"
		printf "it locally (only for its prefix) after running UndertaleModTool for the first time.${CLEAR}\n"
	fi
	if [ $installed -eq 1 ]; then return; fi

	if ! promptInstallMsg "$manager"; then
		return
	fi
	
	cmd=""
	if [ "$manager" = "pacman" ]; then
		cmd="sudo ${manager} -S wine-mono"
	else
		cmd="sudo ${manager} install wine-mono"
	fi

	sh -c "$cmd"
}

if [ "${fetchFromGit}" -eq 1 ]; then
	downloadFromGithub
fi

if [ "${update}" -eq 0 ]; then
	if [ ! -d "${UMT_Path}/pfx" ]; then
		mkdir "${UMT_Path}/pfx"
		printf "${GREEN}Created prefix directory at ${UMT_Path}/pfx${CLEAR}\n"
		
		createWinePref
		ensureWineMono
		installWinRuntime
	fi
else
	moveToUpdate
fi

if [ ! -f "${UMT_Path}/icon.png" ]; then
	printf "${YELLOW}Fetching UMT icon...${CLEAR}\n"
	curl -L -o "${UMT_Path}/icon.png" https://underminersteam.github.io/logo.png
	if [ $? -ne 0 ]; then
		printf "${RED}Failed to fetch UndertaleModTool icon, but continuing anyways (shortcut/desktop file will not have an icon).${CLEAR}\n"
		exit "${CURL_DOWNLOAD_FAILED}"
	fi
fi

cat > "${UMT_Path}/umt_wrapper.sh" <<EOF
export WINEPREFIX=${UMT_Path}/pfx
wine ${UMT_Path}/UndertaleModTool.exe
EOF
chmod +x "${UMT_Path}/umt_wrapper.sh"

cat > "${UMT_Path}/UndertaleModTool.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=UndertaleModTool
Exec=${UMT_Path}/umt_wrapper.sh
Icon=${UMT_Path}/icon.png
Terminal=false
Categories=Utility;
EOF
chmod +x "${UMT_Path}/UndertaleModTool.desktop"
mv "${UMT_Path}/UndertaleModTool.desktop" "${HOME}/.local/share/applications"

if [ "${desktopShortcut}" -eq 1 ]; then
	ln -s "${HOME}/.local/share/applications/UndertaleModTool.desktop" "${HOME}/Desktop/UndertaleModTool"
fi

if [ "${update}" -eq 0 ]; then
	printf "$\n\n${GREEN}Successfully installed UndertaleModTool!${CLEAR}\n"
else
	printf "$\n\n${GREEN}Successfully updated UndertaleModTool!${CLEAR}\n"
fi

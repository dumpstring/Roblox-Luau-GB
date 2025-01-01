$localAppData = [System.Environment]::GetFolderPath('LocalApplicationData')

$pluginsDirectory = Join-Path $localAppData "Roblox\Plugins\gameboyemu.rbxm"

Start-Process "rojo" -ArgumentList "build -o `"$pluginsDirectory`""
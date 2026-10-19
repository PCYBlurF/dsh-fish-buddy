' DSH DaFeiYu desktop pet - hidden launcher
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
script = dir & "\fish-widget.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & script & """"
Set sh = CreateObject("WScript.Shell")
sh.Run cmd, 0, False

# veeam_exporter

## Installation

(Requires NSSM, https://nssm.cc/download)

```powershell
$serviceName = 'veeam_exporter'
$nssm = "c:\veeam_exporter\nssm.exe"
$powershell = (Get-Command powershell).Source
$scriptPath = 'c:\veeam_exporter\main.ps1'
$arguments = '-ExecutionPolicy Bypass -NoProfile -File """{0}"""' -f $scriptPath

& $nssm install $serviceName $powershell $arguments
Start-Service $serviceName

# Substitute the port below with the one you picked for your exporter
New-NetFirewallRule -DisplayName "Veeam Exporter" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9700
```

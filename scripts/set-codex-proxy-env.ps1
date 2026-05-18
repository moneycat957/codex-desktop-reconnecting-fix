param(
    [string]$Proxy = "http://127.0.0.1:10808"
)

setx HTTP_PROXY $Proxy
setx HTTPS_PROXY $Proxy
setx ALL_PROXY $Proxy
setx NO_PROXY "localhost,127.0.0.1,::1"

Write-Host "User proxy environment variables were saved."
Write-Host "Fully quit Codex Desktop and start it again."


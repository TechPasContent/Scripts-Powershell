param (
    [string]$ScriptName = "EmptyTempFile.bat",
    [string]$ScriptPath = "\\DB1.isec.local\Commun\SI\"
)

$ScriptContent = @"
cd %temp%
for /F "delims=" %%i in ('dir /b') do (rmdir "%%i" /s/q || del "%%i" /s/q)
"@


$Script = $ScriptPath + $ScriptName

# If file exists, remove it
if (Test-Path -Path $Script) {
    Remove-Item -Path $Script
}

New-Item -Path $ScriptPath -Name $ScriptName -ItemType File 
Set-Content -Path $Script -Value $ScriptContent

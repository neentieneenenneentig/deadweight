# Creates the Google Play upload key, once:
#   .tools/keys/deadweight-upload.jks     RSA 4096, alias "deadweight", valid 10000 days
#   .tools/keys/upload-key.properties     its random password (never printed)
# Both files are git-ignored and never exported. BACK THEM UP privately (for example in a password
# manager). With Play App Signing a lost upload key can be reset through Play Console support, but
# that takes days.
# The script refuses to overwrite an existing key. tools/build.ps1 reads the properties file.
param([string]$DistinguishedName = 'CN=DEADWEIGHT upload key, O=DEADWEIGHT')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$keyRoot = Join-Path $projectRoot '.tools/keys'
$keystore = Join-Path $keyRoot 'deadweight-upload.jks'
$properties = Join-Path $keyRoot 'upload-key.properties'
if ((Test-Path -LiteralPath $keystore) -or (Test-Path -LiteralPath $properties)) {
    throw "An upload key already exists in $keyRoot. It must never be replaced by accident: move it away by hand first if you really mean to."
}
$java = Get-ChildItem -LiteralPath (Join-Path $projectRoot '.tools/java') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $java) { throw 'Local JDK is missing. Run tools/setup.ps1.' }
$keytool = Join-Path $java.FullName 'bin/keytool.exe'
New-Item -ItemType Directory -Force -Path $keyRoot | Out-Null

# keytool reports progress on stderr, which Windows PowerShell turns into errors under 'Stop'.
function Invoke-Keytool([string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    $output = & $keytool @Arguments 2>&1 | ForEach-Object { "$_" }
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = ($output -join "`n") }
}

# 32 random characters from a cryptographic generator. PKCS12 uses one password for store and key.
$alphabet = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$password = -join ($bytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })

# keytool reads the password from an environment variable, so it never appears on a command line.
$env:DEADWEIGHT_UPLOAD_PASS = $password
try {
    $result = Invoke-Keytool @('-genkeypair', '-keystore', $keystore, '-storetype', 'PKCS12', '-alias', 'deadweight', '-keyalg', 'RSA', '-keysize', '4096', '-validity', '10000', '-dname', $DistinguishedName, '-storepass:env', 'DEADWEIGHT_UPLOAD_PASS', '-keypass:env', 'DEADWEIGHT_UPLOAD_PASS')
    if ($result.Exit -ne 0 -or -not (Test-Path -LiteralPath $keystore)) { throw "keytool failed to create the upload key:`n$($result.Text)" }
    $content = "# DEADWEIGHT Google Play upload key. Private: never commit, share or print.`nstoreFile=deadweight-upload.jks`nkeyAlias=deadweight`nstorePassword=$password`n"
    [IO.File]::WriteAllText($properties, $content, (New-Object Text.UTF8Encoding($false)))
    $listing = Invoke-Keytool @('-list', '-v', '-keystore', $keystore, '-alias', 'deadweight', '-storepass:env', 'DEADWEIGHT_UPLOAD_PASS')
    $fingerprint = ([regex]::Match($listing.Text, 'SHA256:\s*([0-9A-F:]+)')).Groups[1].Value
} finally {
    Remove-Item Env:DEADWEIGHT_UPLOAD_PASS -ErrorAction SilentlyContinue
}
Write-Host "Upload key created: $keystore"
Write-Host "Certificate SHA-256: $fingerprint"
Write-Host 'Back up .tools/keys/ privately now. tools/build.ps1 signs release builds with it.'

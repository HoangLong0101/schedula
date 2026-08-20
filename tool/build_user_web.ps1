param(
  [string]$ConfigFile = ".firebase-config.dev.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot $ConfigFile

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
  throw "Firebase config file not found: $configPath"
}

$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$requiredKeys = @(
  "FIREBASE_API_KEY",
  "FIREBASE_WEB_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_PROJECT_ID",
  "FIREBASE_STORAGE_BUCKET"
)
$missingKeys = $requiredKeys | Where-Object {
  -not $config.PSObject.Properties.Name.Contains($_) -or
  [string]::IsNullOrWhiteSpace([string]$config.$_)
}

if ($missingKeys.Count -gt 0) {
  throw "Firebase config is missing: $($missingKeys -join ', ')"
}

Push-Location $repoRoot
try {
  flutter build web --release --no-pub `
    --dart-define-from-file=$configPath `
    --dart-define=FLAVOR=prod
  if ($LASTEXITCODE -ne 0) {
    throw "User web build failed with exit code $LASTEXITCODE"
  }

  $buildDir = Join-Path $repoRoot "build\web"
  $bundlePath = Join-Path $buildDir "main.dart.js"
  $bootstrapPath = Join-Path $buildDir "flutter_bootstrap.js"
  if (-not (Test-Path -LiteralPath $bundlePath -PathType Leaf) -or
      -not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    throw "User web build did not produce its entry files."
  }

  $bundle = [IO.File]::ReadAllText($bundlePath)
  $missingValues = $requiredKeys | Where-Object {
    -not $bundle.Contains([string]$config.$_)
  }
  if ($missingValues.Count -gt 0) {
    throw "Compiled user bundle is missing Firebase values: $($missingValues -join ', ')"
  }

  $bootstrap = [IO.File]::ReadAllText($bootstrapPath)
  $bundleVersion = (Get-FileHash -Algorithm SHA256 -LiteralPath $bundlePath).Hash.Substring(0, 12).ToLowerInvariant()
  $versionedEntry = "main.dart.js?v=$bundleVersion"
  $updatedBootstrap = $bootstrap.Replace('"mainJsPath":"main.dart.js"', '"mainJsPath":"' + $versionedEntry + '"')
  if ($updatedBootstrap -eq $bootstrap) {
    throw "Could not version the Flutter entry bundle URL."
  }
  [IO.File]::WriteAllText($bootstrapPath, $updatedBootstrap)
} finally {
  Pop-Location
}

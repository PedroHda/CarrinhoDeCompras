# Compila em uma cópia sem acentos e preserva as fontes e os caches existentes.
param(
    [string]$Flutter,
    [string]$AndroidSdk,
    [string]$JavaHome,
    [switch]$PrepareOnly,
    [string]$StageDirectory,
    [switch]$PreflightOnly,
    [switch]$SideBySideTest
)
$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskSource = Join-Path $taskRoot 'mobile'

function Find-TaskPath {
    param([string]$Explicit, [string[]]$Candidates, [string]$Description)
    if ($Explicit) {
        if (!(Test-Path -LiteralPath $Explicit)) { throw "$Description não encontrado em $Explicit" }
        return [IO.Path]::GetFullPath($Explicit)
    }
    foreach ($taskCandidate in $Candidates) {
        if ($taskCandidate -and (Test-Path -LiteralPath $taskCandidate)) {
            return [IO.Path]::GetFullPath($taskCandidate)
        }
    }
    throw "$Description não encontrado. Informe o caminho pelo parâmetro correspondente."
}

$taskFlutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$Flutter = Find-TaskPath -Explicit $Flutter -Description 'Flutter' -Candidates @(
    (Join-Path $taskRoot '.tools\flutter\bin\flutter.bat'),
    (Join-Path $env:USERPROFILE '.codex\toolchains\flutter\bin\flutter.bat'),
    $(if ($taskFlutterCommand) { $taskFlutterCommand.Source }),
    'C:\Setup\flutter\bin\flutter.bat'
)
# Os arquivos .bat do Flutter falham quando o próprio SDK contém parênteses.
# O alias curto do Windows aponta para a mesma instalação sem mover arquivos.
if ($Flutter -match '[ ()]') {
    $taskFileSystem = New-Object -ComObject Scripting.FileSystemObject
    $Flutter = $taskFileSystem.GetFile($Flutter).ShortPath
    if ($Flutter -match '[()]') {
        throw 'O SDK Flutter precisa de um caminho sem parênteses. Informe outro local com -Flutter.'
    }
}
$AndroidSdk = Find-TaskPath -Explicit $AndroidSdk -Description 'Android SDK' -Candidates @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
    (Join-Path $env:USERPROFILE 'AppData\Local\Android\Sdk'),
    (Join-Path $env:USERPROFILE '.codex\toolchains\android-sdk')
)
$JavaHome = Find-TaskPath -Explicit $JavaHome -Description 'JDK' -Candidates @(
    (Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'),
    (Join-Path $env:ProgramFiles 'Android\openjdk\jdk-21.0.8'),
    $env:JAVA_HOME
)
if (!(Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe'))) { throw 'O JDK selecionado não contém bin\java.exe.' }
if (!(Test-Path -LiteralPath (Join-Path $AndroidSdk 'platform-tools\adb.exe'))) { throw 'O Android SDK selecionado não contém platform-tools\adb.exe.' }

$taskPubspec = Get-Content -LiteralPath (Join-Path $taskSource 'pubspec.yaml') -Raw
$taskVersionMatch = [regex]::Match($taskPubspec, '(?m)^version:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)(?:\+([0-9]+))?')
if (!$taskVersionMatch.Success) { throw 'Versão não encontrada em mobile/pubspec.yaml.' }
$taskVersion = $taskVersionMatch.Groups[1].Value
Write-Output "Flutter: $Flutter"
Write-Output "Android SDK: $AndroidSdk"
Write-Output "JDK: $JavaHome"
Write-Output "Versão do aplicativo: $taskVersion (código $($taskVersionMatch.Groups[2].Value))"

# O preflight lê os metadados locais sem iniciar builds nem modificar o Flutter.
$taskFlutterRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path $Flutter -Parent) '..'))
$taskFlutterMetadata = Join-Path $taskFlutterRoot 'bin\cache\flutter.version.json'
if (Test-Path -LiteralPath $taskFlutterMetadata) {
    $taskFlutterVersion = Get-Content -LiteralPath $taskFlutterMetadata -Raw | ConvertFrom-Json
    Write-Output "Flutter instalado: $($taskFlutterVersion.frameworkVersion); Dart: $($taskFlutterVersion.dartSdkVersion)"
    $taskDartRequirement = [regex]::Match($taskPubspec, '(?m)^\s+sdk:\s*["'']?(?:\^|>=)?([0-9]+\.[0-9]+\.[0-9]+)')
    $taskInstalledDart = [regex]::Match($taskFlutterVersion.dartSdkVersion, '[0-9]+\.[0-9]+\.[0-9]+')
    if ($taskDartRequirement.Success -and $taskInstalledDart.Success -and
        ([version]$taskInstalledDart.Value -lt [version]$taskDartRequirement.Groups[1].Value)) {
        throw "O projeto exige Dart $($taskDartRequirement.Groups[1].Value) ou superior. Selecione um Flutter compatível com -Flutter; a instalação atual contém Dart $($taskInstalledDart.Value)."
    }
}
$taskJavaRelease = Join-Path $JavaHome 'release'
if (Test-Path -LiteralPath $taskJavaRelease) {
    $taskJavaVersionMatch = [regex]::Match((Get-Content -LiteralPath $taskJavaRelease -Raw), 'JAVA_VERSION="([0-9]+)')
    if ($taskJavaVersionMatch.Success -and [int]$taskJavaVersionMatch.Groups[1].Value -lt 17) {
        throw 'A compilação Android exige JDK 17 ou superior. Informe -JavaHome com um JDK compatível.'
    }
}
if ($PreflightOnly) { return }

# Cada execução recebe uma cópia nova para não compilar fontes antigas removidas.
if (!$StageDirectory) {
    $taskStageParent = Join-Path $taskSource 'build'
    if ($taskStageParent -match '[^\x00-\x7F]') { $taskStageParent = $env:TEMP }
    $StageDirectory = Join-Path $taskStageParent ("apk-stage-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + "-$PID")
}
$taskStage = [IO.Path]::GetFullPath($StageDirectory)
if ($taskStage -match '[^\x00-\x7F]') { throw 'Escolha uma pasta de compilação sem acentos.' }
if ($taskStage.TrimEnd('\') -eq $taskSource.TrimEnd('\')) { throw 'A cópia de compilação precisa ser diferente da pasta mobile original.' }
New-Item -ItemType Directory -Path $taskStage -Force | Out-Null
# /E copia sem apagar arquivos; build fica excluído inclusive quando contém o stage.
robocopy $taskSource $taskStage /E /XD build .dart_tool .git .gradle .idea /XF local.properties .flutter-plugins-dependencies /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -gt 7) { throw 'Falha na cópia de preparação.' }

$taskPreviousJavaHome = $env:JAVA_HOME
$taskPreviousAndroidHome = $env:ANDROID_HOME
$taskPreviousAndroidSdkRoot = $env:ANDROID_SDK_ROOT
$taskPreviousTestBuild = $env:CARRINHO_SIDE_BY_SIDE_TEST
Push-Location $taskStage
try {
    $env:JAVA_HOME = $JavaHome
    $env:ANDROID_HOME = $AndroidSdk
    $env:ANDROID_SDK_ROOT = $AndroidSdk
    $env:CARRINHO_SIDE_BY_SIDE_TEST = $(if ($SideBySideTest) { 'true' } else { 'false' })
    & $Flutter config --android-sdk $AndroidSdk --jdk-dir $JavaHome
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao configurar a ferramenta Flutter.' }
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha na resolução das dependências.' }
    if ($PrepareOnly) { Write-Output "Preparado em $taskStage"; return }
    & $Flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'A análise estática encontrou problemas.' }
    & $Flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Os testes Flutter falharam.' }
    & $Flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'A compilação Android falhou.' }
    $taskOutput = Join-Path $taskRoot 'artifacts'
    New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
    $taskArtifactSuffix = $(if ($SideBySideTest) { '-teste' } else { '' })
    $taskApk = Join-Path $taskOutput "carrinho-de-compras-$taskVersion$taskArtifactSuffix.apk"
    Copy-Item -LiteralPath (Join-Path $taskStage 'build\app\outputs\flutter-apk\app-release.apk') -Destination $taskApk -Force
    (Get-FileHash -LiteralPath $taskApk -Algorithm SHA256).Hash | Set-Content -LiteralPath (Join-Path $taskOutput "SHA256$taskArtifactSuffix.txt")
    Write-Output "APK disponível em $taskApk"
} finally {
    Pop-Location
    $env:JAVA_HOME = $taskPreviousJavaHome
    $env:ANDROID_HOME = $taskPreviousAndroidHome
    $env:ANDROID_SDK_ROOT = $taskPreviousAndroidSdkRoot
    $env:CARRINHO_SIDE_BY_SIDE_TEST = $taskPreviousTestBuild
}

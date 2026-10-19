# Compila a partir de uma cópia sem acentos, preservando o diretório de trabalho original.
param(
    [string]$Flutter = "$env:USERPROFILE\.codex\toolchains\flutter\bin\flutter.bat",
    [string]$AndroidSdk = "$env:USERPROFILE\.codex\toolchains\android-sdk",
    [string]$JavaHome = 'C:\Program Files\Android\openjdk\jdk-21.0.8',
    [switch]$PrepareOnly
)
$ErrorActionPreference = 'Stop'
# Resolve caminhos absolutos antes de copiar; nunca remove ou move o projeto original.
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskSource = Join-Path $taskRoot 'mobile'
$taskStage = Join-Path $env:USERPROFILE '.codex\builds\carrinho-mobile'
if ($taskStage -match '[^\x00-\x7F]') { throw 'Escolha uma pasta de compilação sem acentos.' }
if (!(Test-Path -LiteralPath $Flutter)) { throw 'Flutter não encontrado. Informe -Flutter com o caminho de flutter.bat.' }
New-Item -ItemType Directory -Path $taskStage -Force | Out-Null
# /E copia subpastas sem apagar arquivos. Caches e caminhos pessoais não são transportados.
robocopy $taskSource $taskStage /E /XD build .dart_tool .git .gradle .idea /XF local.properties .flutter-plugins-dependencies /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -gt 7) { throw 'Falha na cópia de preparação.' }
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
& $Flutter config --android-sdk $AndroidSdk --jdk-dir $JavaHome
if ($LASTEXITCODE -ne 0) { throw 'Falha ao configurar a ferramenta Flutter.' }
Push-Location $taskStage
try {
    # Recria referências de pacotes para a cópia de compilação.
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha na resolução das dependências.' }
    if ($PrepareOnly) { Write-Output "Preparado em $taskStage"; exit 0 }
    # A entrega só é copiada depois das verificações e da compilação release.
    & $Flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'A análise estática encontrou problemas.' }
    & $Flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Os testes Flutter falharam.' }
    & $Flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'A compilação Android falhou.' }
    $taskOutput = Join-Path $taskRoot 'artifacts'
    New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
    $taskApk = Join-Path $taskOutput 'carrinho-de-compras-1.0.0.apk'
    Copy-Item -LiteralPath (Join-Path $taskStage 'build\app\outputs\flutter-apk\app-release.apk') -Destination $taskApk -Force
    (Get-FileHash -LiteralPath $taskApk -Algorithm SHA256).Hash | Set-Content -LiteralPath (Join-Path $taskOutput 'SHA256.txt')
    Write-Output "APK disponível em $taskApk"
} finally {
    # A sessão sempre retorna à pasta anterior, inclusive quando um comando falha.
    Pop-Location
}

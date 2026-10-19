# Inicializa somente o serviço HTTP de consulta, sem banco no servidor.
param([int]$Port = 5080)
$ErrorActionPreference = 'Stop'
$taskProject = Join-Path $PSScriptRoot '..\backend\Carrinho.Api\Carrinho.Api.csproj'
dotnet run --project $taskProject --no-launch-profile --urls "http://127.0.0.1:$Port"
if ($LASTEXITCODE -ne 0) { throw 'O backend foi encerrado com erro.' }

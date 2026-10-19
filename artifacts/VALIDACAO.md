# Validação da entrega — 18/10/2026

## Binário entregue

- Arquivo: `carrinho-de-compras-1.0.0.apk`.
- Tamanho: **105.518.040 bytes** (aproximadamente 100,6 MiB / 105,5 MB).
- SHA-256: `11881142655b83baafea8609cc85a08ab4299d485de856c9573656ea3531341c`.
- Aplicação: **Carrinho de Compras**.
- Pacote: `br.com.carrinhodecompras.carrinho_de_compras`.
- Versão: `1.0.0`, código `1`.
- Android mínimo: API 24, **Android 7.0**.
- Android alvo/compilação: API 36.
- Arquiteturas: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- Assinatura: APK Signature Scheme **v2 válida**, certificado **Android Debug**, para teste por instalação direta.
- Build: `flutter build apk --release`, concluído com código de saída 0.
- Integridade ZIP: todas as entradas passaram na verificação CRC.
- `allowBackup=false` confirmado no manifesto compilado.
- Permissões do binário: internet, câmera, estado da rede e permissão interna de receiver não exportado das bibliotecas AndroidX.

O arquivo `SHA256.txt` contém o mesmo hash para conferir a transferência. Este é um APK release de teste com assinatura de desenvolvimento; não é uma publicação na Play Store.

## Verificações executadas

| Verificação | Resultado |
|---|---|
| `flutter analyze` | Nenhum problema encontrado. |
| `flutter test` | **18 testes aprovados**, incluindo referências visuais. |
| `dotnet test backend/Carrinho.Api.Tests/Carrinho.Api.Tests.csproj` | **13 testes aprovados**. |
| Build Android release | Concluído. |
| `apksigner verify --verbose --print-certs` | Assinatura válida. |
| `aapt2 dump badging` e `aapt2 dump xmltree` | Identidade, ABIs e versões conferidas. |
| ZIP/CRC e SHA-256 do APK | Válidos. |
| Inventário de código | 60 arquivos, 5778 linhas; hashes correspondentes às fontes. |

Os testes abrangem persistência real em SQLite, reabertura de arquivo, valores em centavos, quantidades por peso, duplicação de listas, proteção contra nota duplicada, exclusão com integridade referencial, backup/restauração e rollback, reconhecimento do cenário de oito itens, destinos de rede permitidos, respostas de erro e seleção correta do total fiscal.

## Consulta real da nota apresentada

Foram feitas duas verificações, sem cadastrar a compra no banco do aplicativo:

1. API ASP.NET Core local: retornou os oito itens, data 18/10/2026, total 16153 centavos e soma das linhas de 16153 centavos.
2. Cliente Dart incluído no aplicativo, em consulta direta: retornou os mesmos oito itens, data e valores.

Portanto, o caminho padrão do APK foi testado sem depender de backend hospedado. A disponibilidade futura da Sefaz e outros leiautes não são garantidos por esse teste pontual. A chave fiscal real e a foto não foram incorporadas às fixtures nem ao código.

## Verificação visual

As referências de widgets foram renderizadas com fontes locais e inspecionadas:

- `docs/screenshots/listas.png`.
- `docs/screenshots/lista-aberta.png`.

Essas imagens usam dados sintéticos de QA; não são capturas de um Android físico.

## Testes que dependem do seu aparelho

Nenhum dispositivo Android estava conectado por ADB. Foco da câmera, permissões, captura de foto, seletor de arquivos, compartilhamento e reconhecimento OCR nativo precisam ser conferidos no celular. O APK foi compilado e verificado, mas não foi instalado em hardware físico neste ambiente.

Sugestão de primeiro teste: instalar o APK, criar uma lista, fechar/reabrir o app para verificar persistência, escanear a nota apresentada e conferir os oito itens antes de salvar. Em Ajustes, exportar um backup depois de preencher dados que queira preservar.

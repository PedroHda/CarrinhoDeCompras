# Validação da versão 1.1.0 — 19/10/2026

## APKs entregues

Ambos têm 105.944.844 bytes (aproximadamente 101 MiB), versão 1.1.0, código 2, Android mínimo 7.0/API 24, alvo/compilação API 36 e arquiteturas arm64-v8a, armeabi-v7a e x86_64.

| Arquivo | Aplicativo / identificador | SHA-256 |
|---|---|---|
| `carrinho-de-compras-1.1.0-teste.apk` | Carrinho Teste / `br.com.carrinhodecompras.carrinho_de_compras.teste` | `1d3951b8731460cd711b8c13af7008b37e737e7e8962b648d154c167f13af347` |
| `carrinho-de-compras-1.1.0.apk` | Carrinho de Compras / `br.com.carrinhodecompras.carrinho_de_compras` | `d217a5d478255ba3223ca0a16aec96085e60236730ecb80f73aca039afd43f20` |

Os arquivos SHA256-teste.txt e SHA256.txt contêm os hashes correspondentes. Os binários são distribuídos na release v1.1.0 do GitHub; não integram o histórico Git.

## Instalação preservando o app atual

Use **Carrinho Teste** para instalar ao lado da versão atual. Para testar com os dados existentes, exporte um backup em Ajustes no app atual e restaure o arquivo na cópia de teste. O formato do banco e do backup foi mantido.

A assinatura dos APKs novos é válida (APK Signature Scheme v2, certificado Android Debug). A chave da versão 1.0.0 não estava disponível neste computador, e os certificados são diferentes:

- Certificado da versão 1.0.0 publicada: `53c7954165133e0c8f6fe3e1ce307e4e780d4a1facd064fb3e8dfc31aff60444`.
- Certificado desta entrega: `7f007734dba318e7acd03c55c325a6220a16aa4ca8351dd3f7147898c1d00d08`.

Por isso, o APK com identificador original não atualiza diretamente a versão 1.0.0 publicada. Preserve o backup antes de qualquer reinstalação; a cópia de teste dispensa a remoção do app anterior. As chaves privadas não foram adicionadas ao repositório.

## Verificações realizadas

| Verificação | Resultado |
|---|---|
| `flutter analyze --no-pub` | Nenhum problema encontrado. |
| `flutter test --no-pub` | 46 testes aprovados, incluindo referências visuais. |
| Build Android release normal | Concluído, saída 0. |
| Build Android release de teste separado | Concluído, saída 0. |
| `apksigner verify --verbose --print-certs` | Assinatura v2 válida nos dois APKs. |
| `aapt2 dump badging` / `dump xmltree` | Pacotes, nomes, versões, ABIs, Android mínimo/alvo e atividade de abertura conferidos. |
| ZIP/CRC e SHA-256 | Válidos nos dois binários. |
| Manifesto | `allowBackup=false`; Carrinho Teste aponta para a atividade nativa correta. |
| Script PowerShell | Sintaxe e preflight aprovados; suporte a `-SideBySideTest`. |
| Inventário do código | 65 arquivos e 7625 linhas; referência atualizada. |

Cobertura adicionada: calendário por dia/semana/mês/ano/tudo, limites de períodos e virada de ano, entrada por linha e quantidades fracionadas, lote transacional com rollback, desfazer na posição original, soma de quantidades do mês anterior, preservação de preços fiscais/backups, criação da lista pela interface, edição sem preço, quantidade rápida, marcação de comprado, exclusão por gesto e falha imediata de gravação. Um teste acompanha a conferência da nota até o histórico e seus detalhes.

As telas foram renderizadas com fontes locais e conferidas em `docs/screenshots/listas.png` e `docs/screenshots/lista-aberta.png`. Os fluxos de interação também passaram em 360 × 800. As imagens usam dados sintéticos de teste.

Ambiente: Flutter 3.47.7, Dart 3.13.5, Java 21, Android SDK 36, NDK 28.2.13676358. O SDK Flutter baixado teve seu SHA-256 conferido com o catálogo oficial antes da extração.

## Validação no aparelho

Nenhum Android físico estava conectado. Instalação, permissões, foco da câmera, fotografia, seletor, compartilhamento e OCR nativo ainda dependem do teste no celular. A consulta real da Sefaz e os testes .NET da entrega anterior não foram repetidos; o backend e o serviço fiscal não foram alterados nesta versão.

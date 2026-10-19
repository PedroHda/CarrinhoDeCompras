# Carrinho de Compras

Aplicativo **Flutter/Dart para Android** com listas de supermercado, SQLite privado, histórico de compras, consulta de NFC-e de São Paulo e reconhecimento local de fotos de notas. O backend opcional é **ASP.NET Core 10**.

**[Baixar APK Android para teste — versão 1.1.0](https://github.com/PedroHda/CarrinhoDeCompras/releases/download/v1.1.0/carrinho-de-compras-1.1.0-teste.apk)** · [Release e arquivos de validação](https://github.com/PedroHda/CarrinhoDeCompras/releases/tag/v1.1.0)

A cópia acima aparece como **Carrinho Teste** e instala ao lado do app anterior. Para testar com seus dados, exporte o backup em Ajustes no app atual e restaure na cópia de teste. O [APK com o identificador original](https://github.com/PedroHda/CarrinhoDeCompras/releases/download/v1.1.0/carrinho-de-compras-1.1.0.apk) também está disponível. A assinatura é diferente da versão 1.0.0 publicada, cuja chave não está neste ambiente; ele não a atualiza diretamente. Preserve o backup antes de qualquer reinstalação.

## Novidades da versão 1.1.0

- Histórico por dia, semana (segunda a domingo), mês, ano e todo o período, com setas e seleção de data.
- Listas com produtos e quantidades, sem preços ou total estimado.
- Criação item a item, por texto com um produto por linha ou a partir de todas as compras do mês calendário anterior.
- Na entrada por texto, `Leite` adiciona 1 unidade, `2x Leite` adiciona 2 e `1,5 kg Banana` conserva a quantidade por peso.
- A lista do mês anterior soma quantidades de descrições iguais (ignorando caixa e espaços repetidos), mantém unidades diferentes separadas e começa desmarcada.
- Edição por toque, quantidade pelos botões +/−, marcação no carrinho e exclusão por deslize com **Desfazer**.
- Nova identidade visual em roxo e coral. Notas conferidas continuam salvas no histórico com os valores originais.

## Entrega

- `artifacts/carrinho-de-compras-1.1.0.apk`: APK release de teste, assinado com chave de desenvolvimento.
- `artifacts/carrinho-de-compras-1.1.0-teste.apk`: cópia Carrinho Teste, para instalar ao lado da versão atual.
- `docs/RELATORIO.md`: funcionamento, arquitetura, execução, banco, validação e limitações.
- `docs/LINHA_A_LINHA.md`: inventário do código e explicação de cada linha dos arquivos de implementação/configuração.
- `mobile/`: aplicativo solicitado em Flutter.
- `backend/`: API .NET e testes.
- `scripts/`: comandos reproduzíveis de compilação, execução e documentação.

O diretório `carrinho-de-compras/` contém o protótipo Expo que já existia. Ele foi preservado e não faz parte da compilação Flutter.

## Instalar no Android

Baixe o APK na release acima ou use o arquivo local de `artifacts/`, transfira para seu celular e abra o arquivo. Autorize a instalação pela origem escolhida quando o Android solicitar. Requer Android 7.0 ou superior. O pacote é universal, com ARM de 32/64 bits e x86_64. O binário é distribuído pelas releases; o repositório Git contém seu código-fonte, documentação e checksum.

Na primeira execução, toque em **Nova lista** e escolha uma das três formas de criação. Marque os produtos que colocar no carrinho. Ao concluir uma compra manual, confira estabelecimento, data e valores na tela de conferência. As compras ficam no Histórico. Nenhuma conta é necessária.

Para a nota fiscal, use **Escanear ou fotografar nota**. A consulta direta usa a internet. O reconhecimento de foto é local; confira e corrija os resultados antes de salvar. Se a consulta da Sefaz falhar, as listas continuam disponíveis.

## Desenvolvimento

Use Flutter 3.47.7 / Dart 3.13.5 ou uma versão compatível com `pubspec.lock`, Android SDK 36 e Java 21. As versões efetivamente resolvidas ficam no lockfile.

```powershell
cd mobile
flutter pub get
flutter run
```

No Windows, Gradle e a análise do Dart podem falhar em caminhos com acentos. O script abaixo compila uma cópia sem acentos, executa verificações e copia o APK pronto para `artifacts/`:

```powershell
.\scripts\build-apk.ps1
```

Para gerar a cópia que instala ao lado da versão atual, use `-SideBySideTest` no mesmo script.

O script detecta Flutter, Android SDK e Java, valida a versão do Dart e deriva o nome do APK da versão do projeto. Os parâmetros `-Flutter`, `-AndroidSdk`, `-JavaHome` e `-StageDirectory` permitem usar outros caminhos. `-PreflightOnly` confere o ambiente e `-PrepareOnly` prepara as dependências. A compilação usa uma cópia nova em `mobile/build/` (ou no temporário se o caminho tiver acentos), sem remover os arquivos originais.

## Backend opcional

O app começa em **consulta direta**, sem depender de servidor hospedado. Para testar a API no computador:

```powershell
.\scripts\run-backend.ps1
```

Conecte o Android por USB, autorize a depuração e execute com o ADB:

```powershell
adb reverse tcp:5080 tcp:5080
```

Em **Ajustes → Serviço de consulta**, informe `http://127.0.0.1:5080`. Para um backend publicado, use HTTPS. A conexão por USB só é necessária quando você escolhe usar esse backend local; o funcionamento padrão do APK é independente dele.

Endpoints: `GET /health` e `POST /api/receipts/consult`, com JSON `{"url":"ENDERECO_COMPLETO_DO_QR"}`. O servidor é stateless e não recebe fotos nem armazena listas.

## Testes

```powershell
dotnet test backend/Carrinho.Api.Tests/Carrinho.Api.Tests.csproj
```

Dentro de uma cópia do app em caminho sem acentos:

```powershell
flutter analyze
flutter test
```

Leia o relatório para distinguir testes automatizados, consulta fiscal real e verificações que ainda dependem de um aparelho físico.

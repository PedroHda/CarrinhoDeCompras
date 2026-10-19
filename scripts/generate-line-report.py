"""Gera uma referência numerada de cada linha do código e da configuração entregues."""
from __future__ import annotations

import hashlib
import html
import json
import re
from pathlib import Path

# A raiz é deduzida pelo próprio script, sem depender da pasta atual do terminal.
ROOT = Path(__file__).resolve().parent.parent
DESTINATION = ROOT / "docs" / "LINHA_A_LINHA.md"

# Descreve o papel de cada unidade antes da referência detalhada.
PURPOSES = {
    "formatters.dart": "Conversão decimal exata, arredondamento e apresentação brasileira de valores.",
    "models.dart": "Modelos imutáveis de produtos, listas, rascunhos fiscais e compras, com contratos JSON.",
    "local_database.dart": "Conexão SQLite privada, versão do esquema, tabelas, restrições e índices.",
    "shopping_repository.dart": "Operações persistentes, duplicidade, transações, backup e restauração.",
    "receipt_parser.dart": "Validação de URL fiscal e interpretação de HTML/texto reconhecido.",
    "fiscal_service.dart": "Consulta direta ou pela API opcional, com limites e mensagens de falha.",
    "ocr_service.dart": "Reconhecimento nativo local e reconstrução geométrica de linhas do cupom.",
    "app_view_model.dart": "Estado observável compartilhado; recarga depois das operações persistentes.",
    "main.dart": "Inicialização do Flutter, idioma, banco, repositório e primeira tela.",
    "app.dart": "Composição do MaterialApp com idioma, tema e página inicial.",
    "home_screen.dart": "Navegação por abas, pesquisa e cartões das listas.",
    "list_screen.dart": "Produtos planejados, marcação de comprado e conclusão de uma lista.",
    "history_screen.dart": "Filtros por dia, semana, mês, ano e todo período; detalhes das compras anteriores.",
    "history_period.dart": "Intervalos do calendário local com fim exclusivo e navegação por período.",
    "list_input.dart": "Entrada em lote por linha, com quantidades opcionais e preservação de nomes numéricos.",
    "receipt_review_screen.dart": "Conferência e correção de dados antes de salvar uma compra.",
    "scan_screen.dart": "Scanner de QR, captura/seleção de foto e navegação para conferência.",
    "settings_screen.dart": "Exportação/restauração e preferência de backend.",
    "dialogs.dart": "Formulários reutilizáveis, validações e confirmações de ações.",
    "widgets.dart": "Componentes visuais compartilhados e mensagens transitórias.",
    "theme.dart": "Tema Material 3, cores, fonte e estilos globais.",
    "Program.cs": "Configuração da API, injeção, limites, endpoints e tratamento de falhas.",
    "FiscalUrlPolicy.cs": "Política de domínio/caminho e proteção de destinos, incluindo redirecionamentos.",
    "ReceiptHtmlParser.cs": "Parser DOM fiscal com precisão decimal e detecção de erros do portal.",
    "SefazService.cs": "Consulta HTTP cancelável, limitada e sem persistência no servidor.",
    "ReceiptContracts.cs": "Contratos de entrada, resposta, produtos e erros da API.",
    "build-apk.ps1": "Cópia para caminho sem acentos, verificações, build e entrega do binário.",
    "run-backend.ps1": "Execução local da API de consulta.",
    "generate-line-report.py": "Geração reproduzível desta referência e do inventário com hashes.",
    "consult_receipt.dart": "Diagnóstico de consulta usando o mesmo serviço Dart do aplicativo.",
    "pubspec.yaml": "Identidade, versão, dependências, localização e fontes do aplicativo.",
    "pubspec.lock": "Versões e hashes exatos das dependências resolvidas pelo gerenciador Dart.",
    "AndroidManifest.xml": "Identidade visual, atividade, permissões e regras de integração Android.",
    "network_security_config.xml": "HTTPS padrão com exceções locais para teste por USB/emulador.",
    "ic_cart.xml": "Ícone vetorial nativo do aplicativo, sem imagem externa.",
    "Dockerfile": "Build em estágios e runtime ASP.NET Core 10 para implantação futura.",
}

# Campos recorrentes recebem descrições específicas em vez de textos genéricos.
FIELDS = {
    "id": "identidade estável do registro",
    "name": "nome apresentado ao usuário",
    "description": "descrição original ou conferida do produto",
    "quantityMilli": "quantidade em milésimos da unidade (1096 representa 1,096)",
    "unit": "unidade comercial, por exemplo un, kg ou l",
    "unitPriceCents": "preço unitário inteiro em centavos",
    "totalCents": "total monetário inteiro em centavos",
    "checked": "marcação de produto comprado",
    "createdAt": "data de criação da lista",
    "completed": "situação de conclusão da lista",
    "items": "coleção de linhas da lista ou da compra",
    "receipt": "dados conferidos da compra",
    "merchant": "estabelecimento informado na nota ou na conferência",
    "issuedAt": "data de emissão/compra",
    "accessKey": "chave fiscal usada para detectar duplicação",
    "source": "origem: consulta fiscal, OCR ou registro manual",
    "sourceUrl": "endereço original do QR code, quando disponível",
    "listId": "vínculo opcional entre compra e lista planejada",
    "backendUrl": "endereço opcional do serviço de consulta",
    "loading": "estado de carregamento do armazenamento",
    "loadError": "mensagem de falha de abertura/recarga",
    "model": "modelo de apresentação injetado na tela",
    "repository": "dependência responsável pela persistência",
    "connection": "conexão SQLite aberta",
    "storage": "serviço que fornece a conexão local",
    "_busy": "bloqueio de operações simultâneas",
    "_saving": "indicação de gravação em andamento",
    "_lastUrl": "último endereço fiscal reconhecido nesta sessão",
    "_error": "mensagem de falha exibida na tela",
    "_items": "rascunho editável das linhas da compra",
    "_date": "data editável da compra",
    "_period": "escala de calendário escolhida no histórico",
    "_search": "texto de pesquisa local",
    "_tab": "índice da aba selecionada",
    "_completed": "filtro entre listas ativas e concluídas",
    "_totalEdited": "marca que o total passou a ser escolhido manualmente",
    "_scanner": "controlador da câmera/leitura de QR",
    "_service": "cliente responsável pela consulta fiscal",
    "_form": "chave usada para validar todos os campos do formulário",
    "_merchant": "controlador de edição do estabelecimento",
    "_total": "controlador de edição do total pago",
    "_uuid": "gerador de identificadores independentes do banco",
}

# Widgets e propriedades são descritos pela sua responsabilidade de interface.
WIDGETS = {
    "Scaffold": "organiza a estrutura da página com corpo e barras",
    "AppBar": "monta a barra superior e suas ações",
    "MaterialApp": "configura o aplicativo Material, tema, idioma e navegação",
    "SafeArea": "reserva espaço para barras, recortes e gestos do Android",
    "ListView": "cria conteúdo vertical rolável",
    "SingleChildScrollView": "permite rolar o formulário quando o teclado ocupa espaço",
    "Column": "organiza elementos verticalmente",
    "Row": "organiza elementos horizontalmente",
    "Expanded": "usa o espaço disponível dentro de uma linha ou coluna",
    "Flexible": "permite adaptar a largura do texto ao espaço disponível",
    "Padding": "adiciona margens internas entre componentes",
    "SizedBox": "define espaçamento ou dimensão de um componente",
    "Container": "agrupa conteúdo com dimensões e decoração",
    "Text": "mostra texto ao usuário",
    "SelectableText": "permite selecionar e copiar o texto exibido",
    "TextField": "recebe texto para pesquisa ou edição simples",
    "TextFormField": "recebe entrada integrada à validação do formulário",
    "InputDecoration": "define rótulo, exemplo, ícone e ajuda do campo",
    "DropdownButtonFormField": "permite escolher uma opção validável",
    "DropdownMenuItem": "define uma opção do seletor",
    "Card": "agrupa informações em um cartão visual",
    "ListTile": "compõe uma linha com título, detalhe e ação",
    "Checkbox": "permite marcar ou desmarcar um produto",
    "Icon": "desenha um símbolo da família Material Icons",
    "IconButton": "oferece uma ação identificada por ícone",
    "FilledButton": "cria uma ação principal de alto contraste",
    "OutlinedButton": "cria uma ação secundária com contorno",
    "TextButton": "oferece uma ação auxiliar baseada em texto",
    "CircleAvatar": "mostra um ícone em uma área circular",
    "NavigationBar": "monta a navegação entre as abas principais",
    "NavigationDestination": "define ícone e rótulo de uma aba",
    "IndexedStack": "mantém as abas montadas e mostra a selecionada",
    "ListenableBuilder": "reconstrói a apresentação ao receber alteração do modelo",
    "RefreshIndicator": "permite recarregar com o gesto de puxar a lista",
    "EmptyState": "explica um estado sem dados e orienta o próximo passo",
    "NoteBox": "apresenta uma explicação ou advertência de contexto",
    "SectionHeader": "padroniza título e subtítulo da seção",
    "PopupMenuButton": "reúne ações complementares no menu",
    "PopupMenuItem": "define uma opção do menu de contexto",
    "Form": "agrupa campos para validação conjunta",
    "AlertDialog": "apresenta edição ou decisão em uma janela modal",
    "StatefulBuilder": "mantém estado local do formulário modal",
    "LinearProgressIndicator": "mostra proporção de itens comprados",
    "CircularProgressIndicator": "indica que uma operação ainda está em andamento",
    "MobileScanner": "integra a visualização nativa da câmera e o reconhecimento de códigos",
    "ClipRRect": "recorta o conteúdo nos cantos arredondados",
    "Stack": "sobrepõe câmera, retículo e indicador de processamento",
    "IgnorePointer": "impede a camada decorativa de interceptar os toques",
    "ColoredBox": "preenche uma área com cor sólida",
    "TextStyle": "define a tipografia usada no componente",
    "BoxDecoration": "define fundo, borda e raios do contêiner",
    "ThemeData": "centraliza as escolhas visuais do aplicativo",
    "SnackBar": "exibe mensagem transitória sobre o resultado de uma ação",
}

PROPERTIES = {
    "child": "componente filho único", "children": "lista de componentes filhos",
    "body": "conteúdo principal da página", "title": "título ou rótulo principal",
    "subtitle": "informação complementar", "trailing": "ação ou informação à direita",
    "leading": "ícone ou navegação à esquerda", "padding": "espaçamento interno",
    "onPressed": "ação executada quando o botão é acionado; null desabilita a ação",
    "onTap": "ação de toque no componente", "onChanged": "tratamento de alteração do campo",
    "validator": "regra que devolve mensagem quando o campo é inválido",
    "controller": "controlador que conserva/edita o conteúdo do campo",
    "keyboardType": "tipo de teclado sugerido ao Android",
    "decoration": "apresentação visual do campo ou contêiner",
    "style": "estilo de texto ou botão", "icon": "símbolo visual da ação",
    "label": "texto de identificação", "hintText": "exemplo mostrado no campo vazio",
    "labelText": "rótulo persistente do campo", "helperText": "orientação auxiliar",
    "backgroundColor": "cor da superfície", "color": "cor aplicada ao elemento",
    "fontSize": "tamanho da fonte", "fontWeight": "peso tipográfico",
    "fontFamily": "família de fonte empacotada", "borderRadius": "raio dos cantos",
    "mainAxisAlignment": "distribuição no eixo principal", "crossAxisAlignment": "alinhamento transversal",
    "initialValue": "valor inicial da seleção", "value": "valor atual do componente",
    "items": "opções disponíveis no seletor", "enabled": "estado habilitado ou bloqueado",
    "tooltip": "descrição acessível da ação", "maxLength": "limite de caracteres digitados",
    "selected": "conjunto de opções selecionadas", "selectedIndex": "aba ativa",
    "minSdk": "versão mínima do Android aceita pelo aplicativo",
    "compileSdk": "SDK Android usado para compilar", "targetSdk": "SDK alvo declarado ao Android",
}


def explain(line: str, filename: str, context: str) -> str:
    """Explica linhas por sintaxe, símbolo conhecido e contexto do comentário anterior."""
    value = line.strip()
    if not value:
        return "Linha em branco: separa visualmente blocos, sem efeito de execução."
    if value.startswith(("///", "//", "#", "<!--", "/*", "*", '"""')):
        return "Comentário/documentação: " + value.lstrip("/#* <!-").rstrip("-> ")
    if value.startswith(("import ", "using ", "from ")):
        return "Disponibiliza os tipos e funções do módulo indicado nesta unidade de código."
    if value.startswith("namespace "):
        return "Agrupa os tipos C# no namespace, evitando colisões e indicando sua responsabilidade."
    if value.startswith("@override"):
        return "Declara que o método seguinte implementa um contrato herdado do Flutter/Dart."
    if value.startswith(("[Fact]", "[Theory]", "[InlineData")):
        return "Configura um caso de teste xUnit ou uma combinação de dados para o teste seguinte."
    if "GeneratedRegex" in value:
        return "Solicita ao compilador .NET gerar a expressão regular usada no parser/validador."
    if re.search(r"\b(class|record)\s+\w+", value):
        return "Declara o tipo e seu contrato. " + (context or PURPOSES.get(filename, "Organiza uma responsabilidade da aplicação."))
    if value in {"}", "};", ");", "),", "]", "];", "]),", "])));", "]))", "))", ")))", ");}"} or re.fullmatch(r"[}\]);,]+", value):
        return "Encerra o bloco, chamada ou coleção aberto anteriormente; conserva o agrupamento da expressão."
    if "CREATE TABLE" in value:
        return "Cria a tabela SQLite descrita, com tipos, nulabilidade, chaves e restrições CHECK/FK na instrução SQL."
    if "CREATE INDEX" in value:
        return "Cria índice para acelerar a busca e ordenação sem alterar os dados guardados."
    if "foreign_keys" in value:
        return "Ativa/verifica integridade referencial, incluindo CASCADE e SET NULL."
    if "transaction(" in value:
        return "Inicia operação atômica: todas as alterações confirmam juntas ou são revertidas."
    if re.search(r"\.query\(", value):
        return "Consulta registros SQLite; filtros parametrizados mantêm entrada e SQL separados."
    if re.search(r"\.insert\(", value):
        return "Insere os dados parametrizados; restrições do banco validam a integridade da gravação."
    if re.search(r"\.update\(", value):
        return "Atualiza somente os registros identificados pelo filtro e seus parâmetros."
    if re.search(r"\.delete\(", value):
        return "Remove os registros selecionados; o contexto/transação determina o escopo e permite rollback."
    if "Navigator.push" in value:
        return "Abre uma nova tela e permite aguardar o resultado devolvido quando ela for fechada."
    if "Navigator.pop" in value:
        return "Fecha a tela/modal atual, devolvendo o resultado informado ao chamador."
    if "notifyListeners" in value:
        return "Notifica as telas observadoras depois da atualização do estado persistido."
    if "setState" in value:
        return "Atualiza estado temporário de interface e agenda sua reconstrução visual."
    if re.match(r"(test|testWidgets|group)\(", value):
        return "Define o cenário automatizado nomeado nesta linha; as verificações aparecem no corpo."
    if re.search(r"\b(expect|expectLater|Assert\.)", value):
        return "Compara o resultado observado com o resultado esperado; divergência faz o teste falhar."
    if "matchesGoldenFile" in value:
        return "Compara a imagem renderizada com a referência visual versionada."
    if value.startswith(("if ", "if(", "else if", "} else if")):
        return "Avalia a condição escrita e executa o ramo somente quando ela for verdadeira. " + context
    if value.startswith(("else", "} else")):
        return "Trata o caminho alternativo da condição anterior. " + context
    if re.match(r"(for|while|await for)\b", value):
        return "Percorre os elementos/faixas indicados e aplica o bloco repetidamente. " + context
    if "catch" in value:
        return "Intercepta a falha indicada para preservar dados e apresentar/tratar o erro."
    if "finally" in value:
        return "Executa a limpeza obrigatória tanto no sucesso quanto em caso de falha."
    if value.startswith("try"):
        return "Inicia um bloco protegido cujo erro será tratado pelos catch/finally seguintes."
    if "throw " in value:
        return "Interrompe a operação com o erro explícito; o chamador pode exibir a mensagem."
    if value.startswith("return"):
        return "Devolve a expressão indicada e encerra a função/ramo atual. " + context
    for widget, meaning in WIDGETS.items():
        if re.search(r"\b" + widget + r"(?:\.[A-Za-z]+)?\(", value):
            return "Interface: " + meaning + "."
    prop = re.match(r"([A-Za-z_]\w*)\s*:", value)
    if prop and prop[1] in PROPERTIES:
        return "Define " + PROPERTIES[prop[1]] + " conforme a expressão indicada."
    for field, meaning in FIELDS.items():
        if re.search(r"\b" + re.escape(field) + r"\b", value) and re.search(r"\b(final|late|const|var|public|string|int|String|bool|DateTime)\b", value):
            return "Declara/inicializa " + meaning + ". " + context
    if "await " in value:
        return "Aguarda a operação assíncrona indicada sem bloquear a interface. " + context
    if "Future<" in value or re.match(r"(Widget|String\??|int|bool|void|ThemeData)\s+\w+\(", value):
        return "Define a função ou o contrato de retorno indicado. " + context
    if re.match(r"(final|late|const|var|private|public|protected)\b", value):
        return "Declara um valor, dependência ou membro com o tipo/modificadores indicados. " + context
    if value.startswith(("FROM ", "WORKDIR ", "COPY ", "RUN ", "ENV ", "EXPOSE ", "USER ", "ENTRYPOINT ")):
        return "Instrução Docker: define imagem, diretório, cópia, compilação, ambiente ou processo do estágio indicado."
    if filename.endswith((".yaml", ".lock", ".json", ".properties", ".csproj", ".xml")):
        return "Entrada declarativa de configuração; atribui o valor escrito à chave/elemento do contexto. " + context
    if filename.endswith(".ps1"):
        return "Executa/configura a etapa PowerShell indicada. " + context
    if filename.endswith(".py"):
        return "Etapa do gerador Python: manipula a entrada/saída ou a regra de explicação indicada. " + context
    return "Continua a expressão ou define o argumento indicado. " + (context or PURPOSES.get(filename, "Mantém o contrato e a organização desta unidade."))


def source_files() -> list[Path]:
    """Seleciona somente fonte/configuração, sem recursão por caches, binários ou dependências."""
    files: set[Path] = set()
    for folder in ("mobile/lib", "mobile/test", "mobile/tool", "backend", "scripts"):
        for path in (ROOT / folder).rglob("*"):
            if any(part in {"bin", "obj", "goldens", "__pycache__"} for part in path.relative_to(ROOT).parts):
                continue
            if path.is_file() and (path.suffix in {".dart", ".cs", ".csproj", ".json", ".ps1", ".py"} or path.name in {"Dockerfile", ".dockerignore"}):
                files.add(path)
    for relative in (".gitignore", "mobile/.gitignore", "mobile/pubspec.yaml", "mobile/pubspec.lock", "mobile/analysis_options.yaml", "mobile/android/app/build.gradle.kts", "mobile/android/app/proguard-rules.pro", "mobile/android/build.gradle.kts", "mobile/android/settings.gradle.kts", "mobile/android/gradle.properties", "mobile/android/gradle/wrapper/gradle-wrapper.properties"):
        path = ROOT / relative
        if path.is_file():
            files.add(path)
    # Recursos nativos pequenos são explicados; registradores gerados não são implementação autoral.
    for path in (ROOT / "mobile/android/app/src").rglob("*"):
        if path.is_file() and path.suffix in {".xml", ".kt"}:
            files.add(path)
    return sorted(files, key=lambda path: path.relative_to(ROOT).as_posix())


def main() -> None:
    """Gera tabelas linha a linha e hashes que permitem conferir a versão explicada."""
    files = source_files()
    manifest = []
    body = ["# Código explicado linha por linha", "", "Este anexo acompanha o RELATORIO.md. Cada linha dos arquivos listados aparece com seu número original, conteúdo literal e explicação contextual. Comentários são preservados, e linhas em branco/fechamentos também recebem uma entrada.", "", "Escopo: implementação Flutter/.NET, testes, ferramentas de entrega, configuração e recursos Android textuais. Não inclui o protótipo Expo preexistente, bibliotecas baixadas, caches, binários APK/JAR, fontes/licenças de terceiros, caminhos pessoais nem os próprios relatórios gerados. pubspec.lock é incluído para registrar a resolução reproduzível de dependências. Os arquivos não foram abreviados.", "", "As explicações sintáticas complementam as decisões e exemplos detalhados em RELATORIO.md; linhas de continuação devem ser lidas junto à expressão e ao comentário anterior. O inventário JSON registra SHA-256 de cada fonte.", "", "## Índice", ""]
    for index, path in enumerate(files, 1):
        relative = path.relative_to(ROOT).as_posix()
        body.append(f"{index}. [{relative}](#arquivo-{index})")
    for index, path in enumerate(files, 1):
        raw = path.read_bytes()
        lines = raw.decode("utf-8-sig").splitlines()
        relative = path.relative_to(ROOT).as_posix()
        digest = hashlib.sha256(raw).hexdigest()
        manifest.append({"file": relative, "lines": len(lines), "sha256": digest})
        purpose = PURPOSES.get(path.name, "Teste automatizado de cenários e fronteiras." if "test" in relative.lower() else "Configuração ou integração nativa da aplicação.")
        body += ["", f'<a id="arquivo-{index}"></a>', f"## {relative}", "", purpose, "", f"{len(lines)} linhas. SHA-256: `{digest}`.", "", "| Linha | Código original | Explicação |", "|---:|---|---|"]
        context = purpose
        for number, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith(("///", "//", "#", "<!--")):
                context = stripped.lstrip("/# <!-").rstrip("-> ")
            explanation = explain(line, path.name, context)
            code = html.escape(line).replace("|", "&#124;") or "&nbsp;"
            description = html.escape(explanation).replace("|", "&#124;")
            body.append(f"| {number} | <code>{code}</code> | {description} |")
    total = sum(item["lines"] for item in manifest)
    body += ["", f"Total: **{len(files)} arquivos e {total} linhas explicadas**.", ""]
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    DESTINATION.write_text("\n".join(body), encoding="utf-8")
    (DESTINATION.parent / "CODIGO_INVENTARIO.json").write_text(json.dumps({"files": manifest, "totalFiles": len(files), "totalLines": total}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Gerado: {len(files)} arquivos, {total} linhas, {DESTINATION.stat().st_size} bytes.")


if __name__ == "__main__":
    main()

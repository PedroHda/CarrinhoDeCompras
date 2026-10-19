using System.Globalization;
using System.Text.RegularExpressions;
using AngleSharp.Dom;
using AngleSharp.Html.Parser;
using Carrinho.Api.Contracts;

namespace Carrinho.Api.Services;

/// <summary>Transforma o HTML público em dados; nenhum dado fiscal é inventado.</summary>
public sealed partial class ReceiptHtmlParser
{
    /// <summary>Também permite testes com HTML local, sem depender da Sefaz.</summary>
    public ReceiptResponse Parse(string html, string url)
    {
        // O DOM permite selecionar elementos e ignorar marcações decorativas.
        var document = new HtmlParser().ParseDocument(html);
        var text = document.Body?.TextContent ?? "";
        // O erro da nota real aparece em JavaScript: analisamos o texto sem executá-lo.
        if (html.Contains("Formato de QR-Code", StringComparison.OrdinalIgnoreCase) || html.Contains("QR Code inválido", StringComparison.OrdinalIgnoreCase))
            throw new FiscalException("portal_rejected", "A Sefaz recusou este QR code. Importe uma foto da nota ou tente novamente mais tarde.");
        // Seletores alternativos acomodam versões conhecidas do leiaute móvel.
        var rows = document.QuerySelectorAll("#tabResult tr, table tr[id^='Item'], table tr[id^='item']");
        var items = new List<ReceiptItem>();
        foreach (var row in rows)
        {
            var description = GetText(row, ".txtTit, .descricao, [data-field='description']");
            if (description.Length == 0) continue;
            var quantity = Number(GetText(row, ".Rqtd, .quantidade, [data-field='quantity']"));
            var unitPrice = Number(GetText(row, ".RvlUnit, .valorUnitario, [data-field='unit-price']"));
            var total = Number(GetText(row, ".valor, .valorTotal, [data-field='total']"));
            var unit = GetText(row, ".RUN, .unidade, [data-field='unit']");
            // Campos ausentes nunca se transformam silenciosamente em preço zero.
            if (quantity is null || unitPrice is null || total is null)
                throw new FiscalException("layout_changed", "O portal mudou o formato dos itens. Use a foto da nota para conferir os dados.");
            unit = Regex.Replace(unit, @"^\s*(UN|Unidade)\s*:\s*", "", RegexOptions.IgnoreCase).Trim();
            // Peso é expresso em milésimos; valores financeiros são centavos inteiros.
            items.Add(new ReceiptItem(description, Scale(quantity.Value, 1000), unit.Length == 0 ? "un" : unit.ToLowerInvariant(), Scale(unitPrice.Value, 100), Scale(total.Value, 100)));
        }
        if (items.Count == 0)
        {
            // CAPTCHA requer interação humana: o serviço não tenta contorná-lo.
            if (html.Contains("captcha", StringComparison.OrdinalIgnoreCase) || text.Contains("caracteres da imagem", StringComparison.OrdinalIgnoreCase))
                throw new FiscalException("captcha_required", "O portal pediu uma verificação humana. Abra a consulta ou importe uma foto da nota.");
            throw new FiscalException("receipt_unavailable", "O portal não retornou produtos legíveis. A nota pode estar indisponível ou o leiaute pode ter mudado.");
        }
        var merchant = GetText(document, "#u20, .txtTopo, [data-field='merchant']");
        if (merchant.Length == 0) merchant = "Estabelecimento da nota";
        // .totalNumb também marca a quantidade de itens: prioriza o campo de valor a pagar.
        var totalNode = document.QuerySelector("#totalNota .totalNumb.txtMax, [data-field='receipt-total']")
            ?? document.QuerySelector(".totalNumb.txtMax");
        var genericTotals = document.QuerySelectorAll(".totalNumb");
        if (totalNode is null && genericTotals.Length == 1) totalNode = genericTotals[0];
        var totalValue = Number(totalNode?.TextContent ?? "");
        // Data ausente permanece nula no contrato em vez de virar uma informação fiscal falsa.
        var dateMatch = DatePattern().Match(text);
        string? date = null;
        if (dateMatch.Success && DateTime.TryParseExact(dateMatch.Value, "dd/MM/yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
            date = parsed.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        return new ReceiptResponse(merchant, FiscalUrlPolicy.AccessKey(url), date, totalValue is null ? null : Scale(totalValue.Value, 100), items, "sefaz");
    }

    // TextContent lê texto e nunca executa scripts da página consultada.
    private static string GetText(IParentNode parent, string selector) => parent.QuerySelector(selector)?.TextContent.Trim() ?? "";

    // Extrai o último número de rótulos como "Vl. Unit.: 4,79".
    private static decimal? Number(string text)
    {
        var matches = NumberPattern().Matches(text);
        if (matches.Count == 0) return null;
        var raw = matches[^1].Value;
        if (raw.Contains(',')) raw = raw.Replace(".", "").Replace(',', '.');
        return decimal.TryParse(raw, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var value) ? value : null;
    }

    // O arredondamento comercial é explícito e protegido contra overflow.
    private static long Scale(decimal value, int factor) => checked((long)decimal.Round(value * factor, 0, MidpointRounding.AwayFromZero));

    [GeneratedRegex(@"\d+(?:[.,]\d+)*")]
    private static partial Regex NumberPattern();

    [GeneratedRegex(@"(?<!\d)\d{2}/\d{2}/\d{4}(?!\d)")]
    private static partial Regex DatePattern();
}

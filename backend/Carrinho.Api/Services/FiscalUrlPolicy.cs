using System.Text.RegularExpressions;

namespace Carrinho.Api.Services;

/// <summary>Restringe consultas e redirecionamentos aos portais oficiais de São Paulo.</summary>
public static partial class FiscalUrlPolicy
{
    // A comparação exata impede domínios parecidos e servidores internos (SSRF).
    private static readonly HashSet<string> Hosts = new(StringComparer.OrdinalIgnoreCase)
    {
        "www.nfce.fazenda.sp.gov.br", "nfce.fazenda.sp.gov.br"
    };

    /// <summary>Valida também portas, credenciais e fragmentos antes do acesso HTTP.</summary>
    public static Uri Validate(string? value)
    {
        // Rejeita entradas excessivas ou que não são endereços absolutos.
        if (string.IsNullOrWhiteSpace(value) || value.Length > 4096 || !Uri.TryCreate(value, UriKind.Absolute, out var uri))
            throw new FiscalException("invalid_url", "Informe o endereço completo do QR code da NFC-e.");
        // Redirecionamentos também não podem trocar HTTPS por HTTP ou escolher outra porta.
        if (uri.Scheme != Uri.UriSchemeHttps || uri.Port != 443 || !Hosts.Contains(uri.IdnHost) || uri.UserInfo.Length > 0 || uri.Fragment.Length > 0)
            throw new FiscalException("unsupported_portal", "Esta versão consulta somente NFC-e nos portais HTTPS oficiais de São Paulo.");
        // A política limita o caminho para o serviço não se tornar um proxy geral.
        var path = uri.AbsolutePath.TrimEnd('/');
        if (!path.Equals("/qrcode", StringComparison.OrdinalIgnoreCase) &&
            !path.Equals("/NFCeConsultaPublica/Paginas/ConsultaQRCode.aspx", StringComparison.OrdinalIgnoreCase) &&
            !path.Equals("/NFCeConsultaPublica/Paginas/ConsultaPublica.aspx", StringComparison.OrdinalIgnoreCase))
            throw new FiscalException("unsupported_portal", "O endereço não corresponde à consulta de NFC-e suportada.");
        return uri;
    }

    /// <summary>Obtém a chave original para impedir duplicação da nota no aparelho.</summary>
    public static string? AccessKey(string value)
    {
        // Primeiro decodifica o QR e depois procura a sequência de 44 dígitos.
        var match = AccessKeyPattern().Match(Uri.UnescapeDataString(value));
        return match.Success ? match.Value : null;
    }

    // A expressão é compilada pelo gerador de código do .NET.
    [GeneratedRegex(@"(?<!\d)\d{44}(?!\d)")]
    private static partial Regex AccessKeyPattern();
}

/// <summary>Erro fiscal legível, sem detalhes internos da rede.</summary>
public sealed class FiscalException(string code, string message) : Exception(message)
{
    // O mesmo código é interpretado pelos tratamentos de erro do Flutter.
    public string Code { get; } = code;
}

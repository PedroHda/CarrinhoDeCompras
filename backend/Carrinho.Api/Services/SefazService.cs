using System.Text;
using Carrinho.Api.Contracts;

namespace Carrinho.Api.Services;

/// <summary>Consulta sem persistir dados, limitando tempo, tamanho e redirecionamentos.</summary>
public sealed class SefazService(HttpClient client, ReceiptHtmlParser parser)
{
    /// <summary>O cancelamento acompanha a conexão HTTP do celular.</summary>
    public async Task<ReceiptResponse> ConsultAsync(string url, CancellationToken cancellationToken)
    {
        var destination = FiscalUrlPolicy.Validate(url);
        for (var redirect = 0; redirect < 5; redirect++)
        {
            using var response = await client.GetAsync(destination, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if ((int)response.StatusCode is >= 300 and < 400)
            {
                // Revalida cada destino para evitar redirecionamentos para a rede interna.
                var location = response.Headers.Location ?? throw new FiscalException("portal_error", "Redirecionamento fiscal sem endereço de destino.");
                destination = FiscalUrlPolicy.Validate(new Uri(destination, location).AbsoluteUri);
                continue;
            }
            if (!response.IsSuccessStatusCode)
                throw new FiscalException("portal_unavailable", "A consulta da Sefaz está temporariamente indisponível.");
            // O limite vale mesmo quando a resposta não tem Content-Length.
            const int maximumBytes = 2 * 1024 * 1024;
            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var buffer = new MemoryStream();
            var chunk = new byte[16384];
            int count;
            while ((count = await stream.ReadAsync(chunk, cancellationToken)) > 0)
            {
                if (buffer.Length + count > maximumBytes)
                    throw new FiscalException("response_too_large", "A resposta fiscal excedeu o tamanho suportado.");
                await buffer.WriteAsync(chunk.AsMemory(0, count), cancellationToken);
            }
            // Algumas páginas antigas declaram UTF-8 mas enviam Windows-1252.
            var bytes = buffer.ToArray();
            string html;
            try { html = new UTF8Encoding(false, true).GetString(bytes); }
            catch (DecoderFallbackException) { html = Encoding.GetEncoding(1252).GetString(bytes); }
            return parser.Parse(html, url);
        }
        throw new FiscalException("too_many_redirects", "A consulta fiscal redirecionou mais vezes que o esperado.");
    }
}

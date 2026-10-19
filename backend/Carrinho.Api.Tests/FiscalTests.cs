using System.Text;
using Carrinho.Api.Services;

namespace Carrinho.Api.Tests;

/// <summary>Testes de fronteiras reais: precisão financeira, leiautes e proteção de rede.</summary>
public sealed class FiscalTests
{
    // O dado é sintético; nenhuma chave, CPF ou foto pessoal integra o repositório.
    private const string Url = "https://www.nfce.fazenda.sp.gov.br/qrcode?p=35261000000000000000650010000000011000000000|2|1|1|TESTE";

    [Theory]
    [InlineData("https://www.nfce.fazenda.sp.gov.br.evil.example/qrcode")]
    [InlineData("http://www.nfce.fazenda.sp.gov.br/qrcode")]
    [InlineData("https://127.0.0.1/qrcode")]
    [InlineData("https://www.nfce.fazenda.sp.gov.br:444/qrcode")]
    [InlineData("https://user:pass@www.nfce.fazenda.sp.gov.br/qrcode")]
    [InlineData("https://www.nfce.fazenda.sp.gov.br/admin")]
    public void BlocksArbitraryDestinations(string url) => Assert.Throws<FiscalException>(() => FiscalUrlPolicy.Validate(url));

    [Fact]
    public void ExtractsKeyWithoutRewritingFiscalParameters()
    {
        Assert.Equal(44, FiscalUrlPolicy.AccessKey(Url)!.Length);
        Assert.Equal("www.nfce.fazenda.sp.gov.br", FiscalUrlPolicy.Validate(Url).Host);
    }

    [Fact]
    public void ParsesWeightedItemAndBrazilianCurrency()
    {
        // Um item por peso permite verificar quantidade e arredondamento separadamente.
        const string html = """
        <div id="u20">Mercado de teste</div><p>18/10/2026</p>
        <table id="tabResult"><tr><td><span class="txtTit">Carne</span>
        <span class="Rqtd">Qtde.: 1,096</span><span class="RUN">UN: kg</span>
        <span class="RvlUnit">Vl. Unit.: 42,90</span><span class="valor">47,02</span>
        </td></tr></table><span class="totalNumb">47,02</span>
        """;
        var receipt = new ReceiptHtmlParser().Parse(html, Url);
        Assert.Equal(1096, receipt.Items.Single().QuantityMilli);
        Assert.Equal(4290, receipt.Items.Single().UnitPriceCents);
        Assert.Equal(4702, receipt.Items.Single().TotalCents);
        Assert.Equal(4702, receipt.TotalCents);
        Assert.Equal("2026-10-18", receipt.IssuedAt);
    }

    [Theory]
    [InlineData("<script>Formato de QR-Code não suportado</script>", "portal_rejected")]
    [InlineData("<div>Digite os caracteres da imagem</div>", "captcha_required")]
    [InlineData("<html><body>Serviço indisponível</body></html>", "receipt_unavailable")]
    public void DoesNotInventProductsOnPortalFailure(string html, string code)
    {
        var error = Assert.Throws<FiscalException>(() => new ReceiptHtmlParser().Parse(html, Url));
        Assert.Equal(code, error.Code);
    }

    [Fact]
    public void ItemCountIsNotTheAmountToPay()
    {
        // Reproduz a estrutura observada em SP, com a mesma classe em campos diferentes.
        const string html = """
        <table id="tabResult"><tr><td><span class="txtTit">Arroz</span>
        <span class="Rqtd">1</span><span class="RUN">un</span>
        <span class="RvlUnit">24,90</span><span class="valor">24,90</span></td></tr></table>
        <div id="totalNota"><span class="totalNumb">8</span><span class="totalNumb txtMax">161,53</span></div>
        """;
        Assert.Equal(16153, new ReceiptHtmlParser().Parse(html, Url).TotalCents);
    }

    [Fact]
    public async Task RevalidatesRedirectsBeforeNetworkAccess()
    {
        // Um handler falso garante que o redirecionamento interno não recebe uma segunda chamada.
        var handler = new RedirectHandler();
        using var client = new HttpClient(handler);
        var service = new SefazService(client, new ReceiptHtmlParser());
        var error = await Assert.ThrowsAsync<FiscalException>(() => service.ConsultAsync(Url, CancellationToken.None));
        Assert.Equal("unsupported_portal", error.Code);
        Assert.Equal(1, handler.Count);
    }

    private sealed class RedirectHandler : HttpMessageHandler
    {
        public int Count { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Count++;
            var response = new HttpResponseMessage(System.Net.HttpStatusCode.Redirect);
            response.Headers.Location = new Uri("http://127.0.0.1/private");
            return Task.FromResult(response);
        }
    }
}

using System.Net;
using System.Text;
using System.Threading.RateLimiting;
using Carrinho.Api.Contracts;
using Carrinho.Api.Services;
using Microsoft.AspNetCore.RateLimiting;

// Permite ler páginas fiscais antigas em Windows-1252.
Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
// O ponto de entrada concentra a configuração e a injeção das dependências.
var builder = WebApplication.CreateBuilder(args);
builder.WebHost.ConfigureKestrel(options => options.Limits.MaxRequestBodySize = 8192);
builder.Services.AddSingleton<ReceiptHtmlParser>();
// Redirecionamentos automáticos ficam desligados para revalidar cada destino.
builder.Services.AddHttpClient<SefazService>(client =>
{
    client.Timeout = TimeSpan.FromSeconds(25);
    client.DefaultRequestHeaders.UserAgent.ParseAdd("CarrinhoDeCompras/1.0");
}).ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
{
    AllowAutoRedirect = false,
    AutomaticDecompression = DecompressionMethods.All
});
// Limita consultas por IP, sem armazenar notas ou listas dos usuários.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("fiscal", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 20, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});
var app = builder.Build();
app.UseRateLimiter();
// Verificação simples de conectividade do serviço.
app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "Carrinho.Api", version = "1.0.0" }));
// Fotos e banco SQLite permanecem no aparelho; somente o endereço fiscal é enviado.
app.MapPost("/api/receipts/consult", async (ConsultRequest request, SefazService service, CancellationToken token) =>
{
    try
    {
        return Results.Ok(await service.ConsultAsync(request.Url, token));
    }
    catch (FiscalException error)
    {
        return Results.UnprocessableEntity(new ApiError(error.Code, error.Message));
    }
    catch (OperationCanceledException)
    {
        return Results.Json(new ApiError("timeout", "A consulta demorou demais. Tente novamente ou importe uma foto."), statusCode: 504);
    }
    catch (HttpRequestException)
    {
        return Results.Json(new ApiError("network_error", "Não foi possível acessar a Sefaz neste momento."), statusCode: 502);
    }
}).RequireRateLimiting("fiscal");
// O endereço pode ser alterado por ASPNETCORE_URLS ou pelo argumento --urls.
app.Run();

// Classe parcial para hospedagem do servidor nos testes de integração.
public partial class Program;

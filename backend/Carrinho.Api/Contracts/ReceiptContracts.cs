namespace Carrinho.Api.Contracts;

/// <summary>Entrada: somente o endereço da NFC-e, sem listas nem banco local.</summary>
public sealed record ConsultRequest(string Url);

/// <summary>Inteiros representam milésimos de unidade e centavos, evitando erros binários.</summary>
public sealed record ReceiptItem(string Description, long QuantityMilli, string Unit, long UnitPriceCents, long TotalCents);

/// <summary>Rascunho conferido pelo usuário antes da persistência no celular.</summary>
public sealed record ReceiptResponse(string Merchant, string? AccessKey, string? IssuedAt, long? TotalCents, IReadOnlyList<ReceiptItem> Items, string Source);

/// <summary>Código estável e mensagem legível de uma falha de consulta.</summary>
public sealed record ApiError(string Code, string Message);

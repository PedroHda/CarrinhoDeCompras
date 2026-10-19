# Compila com o SDK oficial .NET 10 e mantém o runtime em uma imagem separada.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source
COPY Carrinho.Api/Carrinho.Api.csproj Carrinho.Api/
RUN dotnet restore Carrinho.Api/Carrinho.Api.csproj
COPY Carrinho.Api/ Carrinho.Api/
RUN dotnet publish Carrinho.Api/Carrinho.Api.csproj -c Release -o /output --no-restore
# A imagem final não precisa do SDK nem de banco de dados.
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /output .
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER app
ENTRYPOINT ["dotnet", "Carrinho.Api.dll"]

# Carrinho de Compras — aplicativo Android

Esta pasta contém o aplicativo Flutter/Dart distribuído nas releases do projeto.

**[Abrir o guia completo](../README.md)** para baixar o APK, instalar no celular, ver as telas, aprender os três modos de criação de listas, usar o histórico e transferir dados por backup.

## Executar

Com o ambiente Flutter/Android configurado, abra o terminal nesta pasta:

```bash
flutter pub get
flutter run
```

Os requisitos e as versões usadas na entrega estão no [guia de desenvolvimento](../README.md#executar).

## Verificar

```bash
flutter analyze
flutter test
```

## Gerar o instalador

Para compilar a cópia **Carrinho Teste** no Windows, execute na **raiz do repositório**:

```powershell
.\scripts\build-apk.ps1 -SideBySideTest
```

Veja [as opções de compilação](../README.md#compilar) para gerar o pacote original, indicar ferramentas ou compilar diretamente em outros sistemas.

O backend .NET é opcional. A pasta `carrinho-de-compras/`, na raiz, contém um protótipo Expo anterior e não participa deste aplicativo Flutter.

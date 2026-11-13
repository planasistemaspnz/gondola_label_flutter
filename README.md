# gondola_label_flutter

App Flutter para impressão de etiquetas de gôndola (preço de produto) em impressoras térmicas
K329, via Bluetooth clássico (RFCOMM/SPP) e protocolo CPCL.

A lógica reutilizável (conexão Bluetooth, geração do payload CPCL, renderização da etiqueta,
widgets de UI) foi extraída para o pacote
[`compex_k329`](https://pub.dev/packages/compex_k329); este app é o consumidor de referência
dele.

## Funcionalidades

- Seleção e pareamento de impressora Bluetooth, com opção de desconexão automática
  ("On-Demand") após cada impressão.
- Preview ao vivo da etiqueta (descrição, preço, preço fracionado, código de barras EAN-13 ou
  Code 128, data) antes de imprimir.
- Seletor de rotação (0°/90°/270°/360°) e parâmetros de posição (offset, margem, altura útil,
  comprimento, cópias).
- Barra de amostras rápidas para preencher o formulário com produtos de exemplo.

## Como rodar

```
flutter pub get
flutter run
```

Requer um dispositivo Android com Bluetooth clássico (o pacote não tem implementação funcional
no iOS — veja o [README do compex_k329](https://pub.dev/packages/compex_k329) para detalhes de
suporte de plataforma).

## Testes

```
flutter test
```

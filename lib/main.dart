import 'package:flutter/material.dart';
import 'package:compex_k329/constants/label_style_constants.dart';
import 'package:compex_k329/models/barcode_type.dart';
import 'package:compex_k329/models/gondola_label_model.dart';
import 'package:compex_k329/services/bluetooth_printer_service.dart';
import 'package:compex_k329/services/cpcl_service.dart';
import 'package:compex_k329/services/printer_preferences_service.dart';
import 'package:compex_k329/widgets/bluetooth_status_card.dart';
import 'package:compex_k329/widgets/device_picker_bottom_sheet.dart';
import 'package:compex_k329/widgets/label_preview_widget.dart';
import 'package:compex_k329/widgets/rotation_selector_widget.dart';
import 'package:compex_k329/widgets/sample_presets_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GondolaLabelApp());
}

class GondolaLabelApp extends StatelessWidget {
  const GondolaLabelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Etiqueta de Gôndola K329',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          primary: LabelStyleConstants.primaryBrandColor,
        ),
        useMaterial3: true,
      ),
      home: const LabelPrinterScreen(),
    );
  }
}

class LabelPrinterScreen extends StatefulWidget {
  const LabelPrinterScreen({super.key});

  @override
  State<LabelPrinterScreen> createState() => _LabelPrinterScreenState();
}

class _LabelPrinterScreenState extends State<LabelPrinterScreen> {
  final BluetoothPrinterService _btService = BluetoothPrinterService();
  GondolaLabelModel _model = GondolaLabelModel();
  BarcodeType _selectedBarcodeType = BarcodeType.ean13;
  BluetoothPrinterDevice? _savedPrinter;

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _fracPriceController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _offsetController = TextEditingController();
  final TextEditingController _feedMarginController = TextEditingController();
  final TextEditingController _shelfHeightController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _copiesController = TextEditingController();

  bool _isPrinting = false;
  bool _isLoadingDevices = false;
  bool _autoDisconnect = true;

  @override
  void initState() {
    super.initState();
    final defaultPreset = SamplePresetsBar.defaultPresets.first;
    _loadSample(
      desc: defaultPreset.description,
      price: defaultPreset.price,
      unit: defaultPreset.unit,
      fracPrice: defaultPreset.fractionalPrice,
      barcode: defaultPreset.barcode,
      barcodeType: defaultPreset.barcodeType,
      length: defaultPreset.lengthMm,
      shelfHeight: defaultPreset.shelfHeightMm,
    );
    _loadSavedPrinter();
    _loadAutoDisconnect();
  }

  @override
  void dispose() {
    _descController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _fracPriceController.dispose();
    _barcodeController.dispose();
    _offsetController.dispose();
    _feedMarginController.dispose();
    _shelfHeightController.dispose();
    _lengthController.dispose();
    _copiesController.dispose();
    super.dispose();
  }

  Future<void> _loadAutoDisconnect() async {
    final ad = await PrinterPreferencesService.getAutoDisconnect();
    if (mounted) setState(() => _autoDisconnect = ad);
  }

  Future<void> _loadSavedPrinter() async {
    final p = await PrinterPreferencesService.getSavedPrinter();
    if (mounted) setState(() => _savedPrinter = p);
  }

  void _loadSample({
    required String desc,
    required String price,
    required String unit,
    required String fracPrice,
    required String barcode,
    BarcodeType barcodeType = BarcodeType.ean13,
    required int length,
    required int shelfHeight,
  }) {
    _descController.text = desc;
    _priceController.text = price;
    _unitController.text = unit;
    _fracPriceController.text = fracPrice;
    _barcodeController.text = barcode;
    _selectedBarcodeType = barcodeType;
    _offsetController.text = '0';
    _feedMarginController.text = '0';
    _shelfHeightController.text = shelfHeight.toString();
    _lengthController.text = length.toString();
    _copiesController.text = '1';
    _updateModel();
  }

  void _updateModel() {
    setState(() {
      _model = _model.copyWith(
        description: _descController.text,
        price: _priceController.text,
        unit: _unitController.text,
        fractionalPrice: _fracPriceController.text,
        barcode: _barcodeController.text,
        barcodeType: _selectedBarcodeType,
        printheadOffsetMm: int.tryParse(_offsetController.text) ?? 0,
        feedMarginMm: int.tryParse(_feedMarginController.text) ?? 0,
        shelfHeightMm: int.tryParse(_shelfHeightController.text) ?? 26,
        lengthMm: int.tryParse(_lengthController.text) ?? 100,
        copies: int.tryParse(_copiesController.text) ?? 1,
      );
    });
  }

  /// Troca o tipo de código de barras selecionado e ajusta o valor digitado
  /// quando ele não é compatível com o novo tipo (ex.: letras num EAN-13).
  void _onBarcodeTypeChanged(BarcodeType type) {
    setState(() {
      _selectedBarcodeType = type;
      if (type.isEan13 && _barcodeController.text.contains(RegExp(r'[a-zA-Z]'))) {
        _barcodeController.text = '7896543215789';
      } else if (type.isCode128 &&
          (_barcodeController.text.isEmpty || _barcodeController.text == '7896543215789')) {
        _barcodeController.text = 'PROD-12345';
      }
    });
    _updateModel();
  }

  void _showBluetoothDisabledSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.deepOrange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openDevicePicker() async {
    final bool isBtOn = await _btService.isBluetoothEnabled();
    if (!isBtOn) {
      _showBluetoothDisabledSnackBar('Ative o Bluetooth do aparelho para buscar impressoras.');
      return;
    }

    setState(() => _isLoadingDevices = true);

    try {
      final List<BluetoothPrinterDevice> devices = await _btService.getDevices();
      setState(() => _isLoadingDevices = false);

      if (!mounted) return;

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum dispositivo Bluetooth encontrado.')),
        );
        return;
      }

      final selected = await DevicePickerBottomSheet.show(
        context,
        devices: devices,
        currentSelected: _savedPrinter,
      );
      if (selected != null) {
        await _selectAndSaveDevice(selected);
      }
    } catch (e) {
      setState(() => _isLoadingDevices = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar dispositivos: $e')),
      );
    }
  }

  Future<void> _selectAndSaveDevice(BluetoothPrinterDevice dev) async {
    await PrinterPreferencesService.saveDefaultPrinter(dev.name, dev.address);
    if (!mounted) return;
    setState(() => _savedPrinter = dev);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impressora "${dev.name}" configurada como padrão!')),
    );
  }

  Future<void> _printLabel() async {
    // 1. Checa se o Bluetooth do aparelho está ativado
    final bool isBtOn = await _btService.isBluetoothEnabled();
    if (!isBtOn) {
      _showBluetoothDisabledSnackBar('O Bluetooth do aparelho está desativado. Ative-o antes de imprimir.');
      return;
    }

    if (!mounted) return;

    if (_savedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma impressora K329 antes de imprimir.')),
      );
      _openDevicePicker();
      return;
    }

    if (!mounted) return;

    setState(() => _isPrinting = true);
    _updateModel();

    final statusNotifier = ValueNotifier<String>('Iniciando impressão...');

    // Exibe o Lazy Loading Modal na tela com bloqueio de toques
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PrintProgressDialog(
        statusNotifier: statusNotifier,
        printerName: _savedPrinter!.name,
      ),
    );

    try {
      final bytes = await CpclService.generatePrintPayload(_model);
      await _btService.printLabelAtomic(
        _savedPrinter!,
        bytes,
        disconnectAfter: _autoDisconnect,
        onProgress: (msg) {
          statusNotifier.value = msg;
        },
      );

      if (!mounted) return;
      // Fecha o Lazy Loading modal
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isPrinting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Etiqueta impressa com sucesso!'),
            ],
          ),
          backgroundColor: LabelStyleConstants.successColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Fecha o Lazy Loading modal
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isPrinting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha na impressão: $e'),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gôndola K329 (Flutter)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              _savedPrinter != null ? Icons.bluetooth_connected : Icons.bluetooth_searching,
              color: _savedPrinter != null ? Colors.indigo[800] : Colors.grey[600],
            ),
            tooltip: _savedPrinter != null ? 'Impressora: ${_savedPrinter!.name}' : 'Selecionar Impressora',
            onPressed: _openDevicePicker,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Bluetooth Card
            BluetoothStatusCard(
              savedPrinter: _savedPrinter,
              isConnected: _btService.isConnected,
              isLoadingDevices: _isLoadingDevices,
              autoDisconnect: _autoDisconnect,
              onOpenPicker: _openDevicePicker,
              onDisconnect: () async {
                await _btService.disconnect();
                if (mounted) setState(() {});
              },
              onToggleAutoDisconnect: (val) async {
                setState(() => _autoDisconnect = val);
                await PrinterPreferencesService.saveAutoDisconnect(val);
              },
            ),
            const SizedBox(height: 10),

            // Rotação Chips
            RotationSelectorWidget(
              currentAngle: _model.rotationAngle,
              onAngleChanged: (angle) => setState(() => _model = _model.copyWith(rotationAngle: angle)),
            ),
            const SizedBox(height: 10),

            // Preview Interativo
            LabelPreviewWidget(model: _model),
            const SizedBox(height: 12),

            // Amostras Rápidas
            SamplePresetsBar(
              onSelectPreset: (preset) => _loadSample(
                desc: preset.description,
                price: preset.price,
                unit: preset.unit,
                fracPrice: preset.fractionalPrice,
                barcode: preset.barcode,
                barcodeType: preset.barcodeType,
                length: preset.lengthMm,
                shelfHeight: preset.shelfHeightMm,
              ),
            ),
            const SizedBox(height: 12),

            // Formulário de Dados
            _buildDataForm(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: _isPrinting ? null : _printLabel,
            style: ElevatedButton.styleFrom(
              backgroundColor: LabelStyleConstants.primaryBrandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print, size: 24),
            label: Text(
              _isPrinting ? 'Imprimindo etiqueta...' : 'IMPRIMIR ETIQUETA K329',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dados do Produto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descrição (1 linha)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _updateModel(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Preço (ex: 28,90)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _updateModel(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unidade',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _updateModel(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fracPriceController,
              decoration: const InputDecoration(
                labelText: 'Preço Fracionado (deixe vazio para omitir)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _updateModel(),
            ),
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text('Tipo de Código:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ChoiceChip(
                  label: const Text('EAN-13', style: TextStyle(fontSize: 12)),
                  selected: _selectedBarcodeType.isEan13,
                  onSelected: (selected) {
                    if (selected) _onBarcodeTypeChanged(BarcodeType.ean13);
                  },
                ),
                ChoiceChip(
                  label: const Text('Code 128', style: TextStyle(fontSize: 12)),
                  selected: _selectedBarcodeType.isCode128,
                  onSelected: (selected) {
                    if (selected) _onBarcodeTypeChanged(BarcodeType.code128);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: _selectedBarcodeType.isEan13
                    ? 'Código EAN-13 (13 dígitos numéricos)'
                    : 'Código Code 128 (alfanumérico)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: _selectedBarcodeType.isEan13 ? TextInputType.number : TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => _updateModel(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text('Parâmetros de Posição e Impressora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _offsetController,
                    decoration: const InputDecoration(
                      labelText: 'Offset Fita (mm)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    onChanged: (_) => _updateModel(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _feedMarginController,
                    decoration: const InputDecoration(
                      labelText: 'Margem Avanço (mm)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateModel(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shelfHeightController,
                    decoration: const InputDecoration(
                      labelText: 'Alt. Útil (mm)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateModel(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lengthController,
                    decoration: const InputDecoration(
                      labelText: 'Comprimento (mm)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateModel(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _copiesController,
                    decoration: const InputDecoration(
                      labelText: 'Cópias',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateModel(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo modal (não dispensável) de progresso exibido durante a impressão atômica
class _PrintProgressDialog extends StatelessWidget {
  final ValueNotifier<String> statusNotifier;
  final String printerName;

  const _PrintProgressDialog({
    required this.statusNotifier,
    required this.printerName,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3.5),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (context, status, _) {
                  return Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                printerName,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

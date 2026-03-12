import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class CustomColorPickerSheet extends StatefulWidget {
  final Color? initialColor;
  final Function(Color) onColorSelected;

  const CustomColorPickerSheet({
    super.key,
    this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<CustomColorPickerSheet> createState() => _CustomColorPickerSheetState();
}

class _CustomColorPickerSheetState extends State<CustomColorPickerSheet> {
  late Color _pickerColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _pickerColor = widget.initialColor ?? Colors.blue;
    _hexController = TextEditingController(
      text: colorToHex(_pickerColor, enableAlpha: false).replaceAll('#', ''),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  // 校验逻辑：尝试将字符串转为 Color，失败则返回 null
  Color? _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示条
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              BlockPicker(
                pickerColor: _pickerColor,
                onColorChanged: (color) => setState(() {
                  _pickerColor = color;
                  _hexController.text = colorToHex(
                    color,
                    enableAlpha: false,
                  ).replaceAll('#', '');
                }),
              ),

              const Divider(height: 30),

              ColorPicker(
                pickerColor: _pickerColor,
                onColorChanged: (color) => setState(() {
                  _pickerColor = color;
                  _hexController.text = colorToHex(
                    color,
                    enableAlpha: false,
                  ).replaceAll('#', '');
                }),
                pickerAreaHeightPercent: 0.3,
                paletteType: PaletteType.hueWheel,
                labelTypes: const [], // 隐藏库自带的 label，我们用自定义的
              ),

              // 自定义 Hex 输入框
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: TextField(
                  controller: _hexController,
                  decoration: const InputDecoration(
                    labelText: 'HEX 颜色代码',
                    prefixText: '#',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final color = _parseColor(value);
                    if (color != null) setState(() => _pickerColor = color);
                  },
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 最终校验
                    final finalColor =
                        _parseColor(_hexController.text) ?? _pickerColor;
                    widget.onColorSelected(finalColor);
                    Navigator.pop(context);
                  },
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

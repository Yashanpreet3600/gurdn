import 'package:flutter/material.dart';

import '../disguise_controller.dart';
import 'face_actions.dart';
import 'secret_entry.dart';

/// A real, working calculator. Typing your safety PIN then "=" opens the
/// real app. Typing 112 + your PIN then "=" starts a silent SOS and keeps
/// showing the calculator.
class CalculatorFace extends StatefulWidget {
  const CalculatorFace({super.key});

  @override
  State<CalculatorFace> createState() => _CalculatorFaceState();
}

class _CalculatorFaceState extends State<CalculatorFace> {
  String _expr = '';
  String _display = '0';

  static const _keys = [
    'C', '()', '%', '÷',
    '7', '8', '9', '×',
    '4', '5', '6', '-',
    '1', '2', '3', '+',
    '±', '0', '.', '=',
  ];

  void _tap(String k) {
    switch (k) {
      case 'C':
        setState(() {
          _expr = '';
          _display = '0';
        });
      case '=':
        _equals();
      case '±':
        setState(() => _expr = _expr.startsWith('-') ? _expr.substring(1) : '-$_expr');
      case '()':
        break; // cosmetic, ignored
      default:
        setState(() {
          _expr += _op(k);
          _display = _expr;
        });
    }
  }

  String _op(String k) => switch (k) { '÷' => '/', '×' => '*', _ => k };

  Future<void> _equals() async {
    // Secret check first, on the digits only.
    final digits = _expr.replaceAll(RegExp(r'[^0-9]'), '');
    final action = await SecretEntry.evaluate(digits);
    if (action != SecretAction.none) {
      _expr = '';
      _display = '0';
      if (mounted) setState(() {});
      await FaceActions.handle(context, action);
      return;
    }
    // Otherwise, really calculate.
    setState(() {
      try {
        _display = _eval(_expr);
        _expr = _display;
      } catch (_) {
        _display = 'Error';
        _expr = '';
      }
    });
  }

  // A tiny, safe arithmetic evaluator (+ - * / %), left-to-right with
  // * / % before + -. No eval(), no packages.
  String _eval(String input) {
    final tokens = _tokenize(input);
    if (tokens.isEmpty) return '0';
    // pass 1: * / %
    final out = <String>[tokens.first];
    for (var i = 1; i < tokens.length - 1; i += 2) {
      final op = tokens[i], b = double.parse(tokens[i + 1]);
      if (op == '*' || op == '/' || op == '%') {
        final a = double.parse(out.removeLast());
        out.add((op == '*' ? a * b : op == '/' ? a / b : a % b).toString());
      } else {
        out.add(op);
        out.add(b.toString());
      }
    }
    // pass 2: + -
    var acc = double.parse(out.first);
    for (var i = 1; i < out.length - 1; i += 2) {
      final op = out[i], b = double.parse(out[i + 1]);
      acc = op == '+' ? acc + b : acc - b;
    }
    // Trim ".0"
    return acc == acc.roundToDouble() && acc.abs() < 1e15
        ? acc.toInt().toString()
        : acc.toString();
  }

  List<String> _tokenize(String s) {
    final tokens = <String>[];
    final num = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if ('0123456789.'.contains(ch)) {
        num.write(ch);
      } else if ('+-*/%'.contains(ch)) {
        if (num.isEmpty && (ch == '-') && tokens.isEmpty) {
          num.write(ch); // leading negative
        } else {
          if (num.isNotEmpty) {
            tokens.add(num.toString());
            num.clear();
          }
          tokens.add(ch);
        }
      }
    }
    if (num.isNotEmpty) tokens.add(num.toString());
    return tokens;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF17181C) : const Color(0xFFF2F3F7);
    final fg = dark ? Colors.white : Colors.black87;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      home: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 56, fontWeight: FontWeight.w300, color: fg),
                  ),
                ),
              ),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(10),
                children: [
                  for (final k in _keys) _CalcKey(label: k, onTap: () => _tap(k)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalcKey extends StatelessWidget {
  const _CalcKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isOp = '÷×-+=%'.contains(label);
    final bg = label == '='
        ? const Color(0xFFF59E0B)
        : isOp
            ? (dark ? const Color(0xFF2A2C33) : const Color(0xFFE2E4EC))
            : (dark ? const Color(0xFF23252B) : Colors.white);
    final fg = label == '=' ? Colors.white : (dark ? Colors.white : Colors.black87);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 24, color: fg, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

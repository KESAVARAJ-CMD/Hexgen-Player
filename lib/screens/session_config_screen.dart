import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/session_status_service.dart';
import '../core/services/sessions_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_glass_backdrop.dart';

class OverConfig {
  double ballSpeed;
  String selectedArm;
  String selectedBowlerType; // 'Pace' or 'Spin'
  String selectedLength;     // 'SLOT', 'FULL', 'GOOD', 'SHORT'
  String selectedVariation;  // 'Straight', 'Swing', 'Seam' (or for spin: 'Straight', 'Off Spin', 'Leg Spin')
  String selectedDirection;  // 'In' or 'Out'
  String selectedLevel;      // 'Basic', 'Medium', 'High'
  int selectedLine;          // 1 to 5 (L1 - L5)
  bool randomSpin;
  bool randomLength;
  bool randomSpeed;

  OverConfig({
    this.ballSpeed = 50.0,
    this.selectedArm = 'Right Arm',
    this.selectedBowlerType = '',
    this.selectedLength = '',
    this.selectedVariation = '',
    this.selectedDirection = '',
    this.selectedLevel = '',
    this.selectedLine = 0,
    this.randomSpin = false,
    this.randomLength = false,
    this.randomSpeed = false,
  });

  OverConfig clone() {
    return OverConfig(
      ballSpeed: ballSpeed,
      selectedArm: selectedArm,
      selectedBowlerType: selectedBowlerType,
      selectedLength: selectedLength,
      selectedVariation: selectedVariation,
      selectedDirection: selectedDirection,
      selectedLevel: selectedLevel,
      selectedLine: selectedLine,
      randomSpin: randomSpin,
      randomLength: randomLength,
      randomSpeed: randomSpeed,
    );
  }
}

class SessionConfigScreen extends StatefulWidget {
  final bool isCreatingPracticeSession;
  final String? initialSessionTitle;
  final int initialOversCount;
  final SessionItem? sessionToEdit;
  final SessionItem? templateSession;

  const SessionConfigScreen({
    super.key,
    this.isCreatingPracticeSession = true,
    this.initialSessionTitle,
    this.initialOversCount = 1,
    this.sessionToEdit,
    this.templateSession,
  });

  @override
  State<SessionConfigScreen> createState() => _SessionConfigScreenState();
}

class _SessionConfigScreenState extends State<SessionConfigScreen> {
  int _totalOvers = 1;
  int _selectedOver = 1;
  int _intervalBetweenBalls = 5;
  int _intervalBetweenOvers = 10;
  final TextEditingController _sessionNameController = TextEditingController();

  final Map<int, OverConfig> _overConfigs = {
    for (int i = 1; i <= 10; i++) i: OverConfig(),
  };

  void _updateTotalOvers(int newTotal) {
    if (newTotal < 1 || newTotal > 10) return;
    setState(() {
      _totalOvers = newTotal;
      if (_selectedOver > _totalOvers) {
        _selectedOver = _totalOvers;
      }
      for (int i = 1; i <= _totalOvers; i++) {
        _overConfigs.putIfAbsent(i, () => OverConfig());
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final s = widget.sessionToEdit ?? widget.templateSession;
    if (s != null) {
      _sessionNameController.text = s.name.isNotEmpty ? s.name : 'Practice';
      _intervalBetweenBalls = s.intervalBetweenBalls;
      _intervalBetweenOvers = s.intervalBetweenOvers;

      final speedVal = double.tryParse(s.speed.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 50.0;

      int count = s.overs.isNotEmpty ? s.overs.length : 6;
      final match = RegExp(r'\d+').firstMatch(s.oversCount);
      if (match != null) {
        final parsed = int.tryParse(match.group(0)!);
        if (parsed != null && parsed >= 1 && parsed <= 10) {
          count = parsed;
        }
      }
      _totalOvers = count;

      for (int i = 1; i <= 10; i++) {
        double overSpeed = speedVal;
        String overVariation = s.variation;
        String overBowlerType = s.bowlerType;
        String overDirection = s.direction;
        int overLine = 3;
        String overLength = s.length.toUpperCase();
        if (!['SLOT', 'FULL', 'GOOD', 'SHORT'].contains(overLength)) {
          overLength = 'GOOD';
        }

        if (i <= s.overs.length) {
          final overMap = s.overs[i - 1];
          if (overMap['speed'] != null) {
            overSpeed = double.tryParse(overMap['speed'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? speedVal;
          }
          if (overMap['type'] != null) {
            final typeStr = overMap['type'].toString();
            if (typeStr.contains('Spin')) {
              overBowlerType = 'Spin';
            } else if (typeStr.contains('Pace')) {
              overBowlerType = 'Pace';
            }
          }
          if (overMap['variation'] != null) {
            overVariation = overMap['variation'].toString();
          }
          if (overMap['lineNo'] != null || overMap['session_line'] != null) {
            overLine = int.tryParse((overMap['lineNo'] ?? overMap['session_line']).toString()) ?? 3;
          }
          if (overMap['length'] != null) {
            final lUpper = overMap['length'].toString().toUpperCase();
            if (['SLOT', 'FULL', 'GOOD', 'SHORT'].contains(lUpper)) {
              overLength = lUpper;
            }
          }
        }

        if (overBowlerType == 'Spin') {
          if (overVariation != 'Off Spin' && overVariation != 'Leg Spin') {
            overVariation = 'Off Spin';
          }
        }

        _overConfigs[i] = OverConfig(
          ballSpeed: overSpeed,
          selectedArm: s.armType,
          selectedBowlerType: overBowlerType,
          selectedLength: overLength,
          selectedVariation: overVariation,
          selectedDirection: overDirection,
          selectedLevel: s.level,
          selectedLine: overLine,
        );
      }
    } else {
      _totalOvers = (widget.initialOversCount >= 1 && widget.initialOversCount <= 10)
          ? widget.initialOversCount
          : 1;
      _sessionNameController.text = 'Practice';
    }
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _capitalizeFirst(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  OverConfig get _currentConfig => _overConfigs[_selectedOver]!;

  double get _ballSpeed => _currentConfig.ballSpeed;
  set _ballSpeed(double val) => _currentConfig.ballSpeed = val;

  String get _selectedArm => _currentConfig.selectedArm;
  set _selectedArm(String val) => _currentConfig.selectedArm = val;

  String get _selectedBowlerType => _currentConfig.selectedBowlerType;
  set _selectedBowlerType(String val) => _currentConfig.selectedBowlerType = val;

  String get _selectedLength => _currentConfig.selectedLength;
  set _selectedLength(String val) => _currentConfig.selectedLength = val;

  String get _selectedVariation => _currentConfig.selectedVariation;
  set _selectedVariation(String val) => _currentConfig.selectedVariation = val;

  String get _selectedDirection => _currentConfig.selectedDirection;
  set _selectedDirection(String val) => _currentConfig.selectedDirection = val;

  String get _selectedLevel => _currentConfig.selectedLevel;
  set _selectedLevel(String val) => _currentConfig.selectedLevel = val;

  int get _selectedLine => _currentConfig.selectedLine;
  set _selectedLine(int val) => _currentConfig.selectedLine = val;

  void _onBowlerTypeChanged(String type) {
    setState(() {
      _selectedBowlerType = type;
      if (type == 'Pace') {
        if (_selectedVariation != 'Straight' &&
            _selectedVariation != 'Swing' &&
            _selectedVariation != 'Seam') {
          _selectedVariation = '';
        }
      } else {
        if (_selectedVariation != 'Off Spin' && _selectedVariation != 'Leg Spin') {
          _selectedVariation = '';
        }
      }
    });
  }

  void _onVariationTapped(String variation, String type) {
    if (_selectedBowlerType.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select Bowler Type (Pace or Spin) first!',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _selectedBowlerType = type;
      _selectedVariation = variation;
      if (type == 'Pace' && (variation == 'Swing' || variation == 'Seam')) {
        if (_selectedDirection != 'In' && _selectedDirection != 'Out') {
          _selectedDirection = 'In';
        }
      }
    });
  }

  bool _validateCurrentOverConfig() {
    List<String> missingFields = [];

    if (_selectedBowlerType.isEmpty) {
      missingFields.add('Bowler Type');
    }
    if (_selectedVariation.isEmpty) {
      missingFields.add('Variation');
    }
    final isPace = _selectedBowlerType == 'Pace';
    if ((!isPace || _selectedVariation != 'Straight') && _selectedLevel.isEmpty) {
      missingFields.add('Level');
    }
    if (_selectedLine == 0) {
      missingFields.add('Line');
    }
    if (_selectedLength.isEmpty) {
      missingFields.add('Length');
    }

    if (missingFields.isNotEmpty) {
      final msg = 'Please select ${missingFields.join(', ')} for Over $_selectedOver before saving!';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE11D48),
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
    return true;
  }

  void _onBottomButtonPressed() {
    if (!_validateCurrentOverConfig()) return;

    if (_selectedOver < _totalOvers) {
      setState(() {
        _selectedOver += 1;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Over ${_selectedOver - 1} saved! Now configuring Over $_selectedOver of $_totalOvers',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.navyBlue,
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } else {
      _onSave();
    }
  }

  Future<void> _onSave() async {
    for (int i = 1; i <= _totalOvers; i++) {
      final config = _overConfigs[i] ?? _currentConfig;
      final isPace = config.selectedBowlerType == 'Pace';
      final needsLevel = !isPace || config.selectedVariation != 'Straight';

      if (config.selectedBowlerType.isEmpty ||
          config.selectedVariation.isEmpty ||
          config.selectedLine == 0 ||
          config.selectedLength.isEmpty ||
          (needsLevel && config.selectedLevel.isEmpty)) {
        setState(() {
          _selectedOver = i;
        });
        _validateCurrentOverConfig();
        return;
      }
    }

    final rawTitle = _sessionNameController.text.trim();
    final sessionTitle = rawTitle.isNotEmpty
        ? _capitalizeWords(rawTitle)
        : (widget.sessionToEdit?.name ?? 'Practice');

    final List<Map<String, dynamic>> generatedOvers = [];
    for (int i = 1; i <= _totalOvers; i++) {
      final config = _overConfigs[i] ?? _currentConfig;
      final bowlerType = config.selectedBowlerType;
      final variation = config.selectedVariation;
      final length = config.selectedLength;
      final direction = config.selectedDirection.isNotEmpty ? config.selectedDirection : 'In';
      final level = config.selectedLevel.isNotEmpty ? config.selectedLevel : 'Basic';
      final lineNo = config.selectedLine;

      generatedOvers.add({
        'over': 'Over ${i.toString().padLeft(2, '0')}',
        'summary': '6 Balls • ${config.ballSpeed.toStringAsFixed(1)} km/h • $variation',
        'speed': '${config.ballSpeed.toStringAsFixed(1)} km/h',
        'type': '$bowlerType - $variation',
        'armType': config.selectedArm,
        'bowlerType': bowlerType,
        'length': length,
        'variation': variation,
        'direction': direction,
        'level': level,
        'lineNo': lineNo,
        'session_line': lineNo,
        'randomSpin': config.randomSpin,
        'randomLength': config.randomLength,
        'randomSpeed': config.randomSpeed,
      });
    }

    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = now.minute.toString().padLeft(2, '0');
    final timeStr = '${hour.toString().padLeft(2, '0')}:$minuteStr $ampm';

    if (widget.sessionToEdit != null) {
      final existing = widget.sessionToEdit!;
      final machineId = 'HEX-${(existing.id.hashCode.abs() % 9000 + 1000)}';
      final updatedSession = existing.copyWith(
        name: sessionTitle,
        oversCount: '$_totalOvers ${_totalOvers == 1 ? "Over" : "Overs"}',
        speed: '${_ballSpeed.toStringAsFixed(1)} km/h',
        armType: _currentConfig.selectedArm,
        bowlerType: _selectedBowlerType,
        length: _selectedLength,
        variation: _selectedVariation,
        direction: _currentConfig.selectedDirection,
        level: _selectedLevel,
        overs: generatedOvers,
        intervalBetweenBalls: _intervalBetweenBalls,
        intervalBetweenOvers: _intervalBetweenOvers,
      );

      await SessionsService().updateSession(updatedSession);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => SessionQrShareDialog(
          sessionItem: updatedSession,
          machineId: machineId,
          intervalBetweenBalls: _intervalBetweenBalls,
          intervalBetweenOvers: _intervalBetweenOvers,
          onDone: () {
            Navigator.pop(ctx); // Close dialog
            Navigator.pop(context, true); // Close SessionConfigScreen
          },
        ),
      );
      return;
    }

    final nextIndex = SessionsService().sessions.length + 1;
    final sessionTag = 'Session $nextIndex';
    final machineId = 'HEX-${(sessionTitle.hashCode.abs() % 9000 + 1000)}';

    final newSession = SessionItem(
      id: 'SES-${nextIndex.toString().padLeft(2, '0')}',
      title: sessionTag,
      name: sessionTitle.trim().isNotEmpty ? sessionTitle.trim() : sessionTag,
      date: dateStr,
      time: timeStr,
      lane: 'Hexgen Turf',
      coach: 'Self Practice',
      oversCount: '$_totalOvers ${_totalOvers == 1 ? "Over" : "Overs"}',
      speed: '${_ballSpeed.toStringAsFixed(1)} km/h',
      armType: _currentConfig.selectedArm,
      bowlerType: _selectedBowlerType,
      length: _selectedLength,
      variation: _selectedVariation,
      direction: _currentConfig.selectedDirection,
      level: _selectedLevel,
      isUpcoming: true,
      overs: generatedOvers,
      intervalBetweenBalls: _intervalBetweenBalls,
      intervalBetweenOvers: _intervalBetweenOvers,
    );

    // Save persistently into SessionsService and sync with Cloud
    final savedSession = await SessionsService().addSession(newSession);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SessionQrShareDialog(
        sessionItem: savedSession,
        machineId: machineId,
        intervalBetweenBalls: _intervalBetweenBalls,
        intervalBetweenOvers: _intervalBetweenOvers,
        onDone: () {
          Navigator.pop(ctx); // Close dialog
          Navigator.pop(context, true); // Close SessionConfigScreen
        },
      ),
    );
  }

  void _onCopyToAllOvers() {
    final current = _currentConfig;
    setState(() {
      for (int i = 1; i <= _totalOvers; i++) {
        _overConfigs[i] = current.clone();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Over $_selectedOver settings copied to all $_totalOvers overs!',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.navyBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPace = _selectedBowlerType == 'Pace';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CyberGlassBackdrop(
        showOrbs: false,
        child: SafeArea(
          child: Column(
            children: [
              // ── 1. Top Header Bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppTheme.navyBlue,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.sessionToEdit != null
                            ? 'EDIT SESSION CONFIGURATION'
                            : _capitalizeFirst(widget.initialSessionTitle ?? 'SESSION CONFIGURATION'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navyBlue,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _overConfigs[_selectedOver] = OverConfig();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Over reset to default configuration'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.navyBlue,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── 2. Scrollable Body ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Session Name & Overs Controls ──────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Session Name Input
                            Row(
                              children: [
                                const Icon(
                                  Icons.edit_note_rounded,
                                  color: AppTheme.electricBlue,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _sessionNameController,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.navyBlue,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Session Name (e.g. Batting Practice 1)',
                                      hintStyle: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.normal,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFFE2E8F0), height: 1),
                            const SizedBox(height: 12),

                            // Total Overs Stepper & Copy to All
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Over $_selectedOver of $_totalOvers',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.navyBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Stepper
                                    Container(
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_rounded, size: 14),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            color: _totalOvers > 1 ? AppTheme.navyBlue : const Color(0xFFCBD5E1),
                                            onPressed: _totalOvers > 1 ? () => _updateTotalOvers(_totalOvers - 1) : null,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Text(
                                              '$_totalOvers Ovs',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.navyBlue,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_rounded, size: 14),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            color: _totalOvers < 10 ? AppTheme.electricBlue : const Color(0xFFCBD5E1),
                                            onPressed: _totalOvers < 10 ? () => _updateTotalOvers(_totalOvers + 1) : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                              ],
                            ),
                            const SizedBox(height: 10),

                            // Over Chips (1 to _totalOvers)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  ...List.generate(_totalOvers, (index) {
                                    final overNum = index + 1;
                                    final isSelected = _selectedOver == overNum;

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () => setState(() => _selectedOver = overNum),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          width: 40,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            gradient: isSelected ? AppTheme.primaryCtaGradient : null,
                                            color: isSelected ? null : Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                                              width: 1.1,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: AppTheme.electricBlue.withValues(alpha: 0.35),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.02),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$overNum',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w900,
                                                color: isSelected ? Colors.white : AppTheme.navyBlue,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  if (_totalOvers < 10)
                                    GestureDetector(
                                      onTap: () => _updateTotalOvers(_totalOvers + 1),
                                      child: Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppTheme.electricBlue.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.add_rounded, color: AppTheme.electricBlue, size: 18),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── 0. ARM TYPE ────────────────────────────────────────
                      _buildSectionHeader('ARM TYPE'),
                      Row(
                        children: [
                          _buildSelectableButton(
                            label: 'Right Arm',
                            isSelected: _selectedArm == 'Right Arm',
                            onTap: () => setState(() => _selectedArm = 'Right Arm'),
                          ),
                          const SizedBox(width: 10),
                          _buildSelectableButton(
                            label: 'Left Arm',
                            isSelected: _selectedArm == 'Left Arm',
                            onTap: () => setState(() => _selectedArm = 'Left Arm'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── 1. BOWLER TYPE ─────────────────────────────────────
                      _buildSectionHeader('BOWLER TYPE'),
                      Row(
                        children: [
                          _buildSelectableButton(
                            label: 'Pace',
                            isSelected: _selectedBowlerType == 'Pace',
                            onTap: () => _onBowlerTypeChanged('Pace'),
                          ),
                          const SizedBox(width: 10),
                          _buildSelectableButton(
                            label: 'Spin',
                            isSelected: _selectedBowlerType == 'Spin',
                            onTap: () => _onBowlerTypeChanged('Spin'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── 2. SELECT VARIATION ────────────────────────────────
                      _buildSectionHeader('SELECT VARIATION'),
                      if (_selectedBowlerType.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            '⚠️ Please select Bowler Type (Pace or Spin) above first',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ],
                      if (isPace) ...[
                        Row(
                          children: [
                            _buildSelectableButton(
                              label: 'Straight',
                              isSelected: _selectedVariation == 'Straight',
                              onTap: () => _onVariationTapped('Straight', 'Pace'),
                            ),
                            const SizedBox(width: 8),
                            _buildSelectableButton(
                              label: 'Swing',
                              isSelected: _selectedVariation == 'Swing',
                              onTap: () => _onVariationTapped('Swing', 'Pace'),
                            ),
                            const SizedBox(width: 8),
                            _buildSelectableButton(
                              label: 'Seam',
                              isSelected: _selectedVariation == 'Seam',
                              onTap: () => _onVariationTapped('Seam', 'Pace'),
                            ),
                          ],
                        ),
                        if (_selectedVariation == 'Swing') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildSelectableButton(
                                label: 'In Swing',
                                isSelected: _selectedDirection == 'In',
                                onTap: () => setState(() => _selectedDirection = 'In'),
                              ),
                              const SizedBox(width: 8),
                              _buildSelectableButton(
                                label: 'Out Swing',
                                isSelected: _selectedDirection == 'Out',
                                onTap: () => setState(() => _selectedDirection = 'Out'),
                              ),
                            ],
                          ),
                        ] else if (_selectedVariation == 'Seam') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildSelectableButton(
                                label: 'In Seam',
                                isSelected: _selectedDirection == 'In',
                                onTap: () => setState(() => _selectedDirection = 'In'),
                              ),
                              const SizedBox(width: 8),
                              _buildSelectableButton(
                                label: 'Out Seam',
                                isSelected: _selectedDirection == 'Out',
                                onTap: () => setState(() => _selectedDirection = 'Out'),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            _buildSelectableButton(
                              label: 'Off Spin',
                              isSelected: _selectedVariation == 'Off Spin',
                              onTap: () => _onVariationTapped('Off Spin', 'Spin'),
                            ),
                            const SizedBox(width: 10),
                            _buildSelectableButton(
                              label: 'Leg Spin',
                              isSelected: _selectedVariation == 'Leg Spin',
                              onTap: () => _onVariationTapped('Leg Spin', 'Spin'),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 18),

                      // ── 3. CHOOSE LEVELS ───────────────────────────────────
                      if (!isPace || _selectedVariation != 'Straight') ...[
                        _buildSectionHeader('CHOOSE LEVELS'),
                        Row(
                          children: [
                            _buildSelectableButton(
                              label: 'Basic',
                              isSelected: _selectedLevel == 'Basic',
                              onTap: () => setState(() => _selectedLevel = 'Basic'),
                            ),
                            const SizedBox(width: 8),
                            _buildSelectableButton(
                              label: 'Medium',
                              isSelected: _selectedLevel == 'Medium',
                              onTap: () => setState(() => _selectedLevel = 'Medium'),
                            ),
                            const SizedBox(width: 8),
                            _buildSelectableButton(
                              label: 'High',
                              isSelected: _selectedLevel == 'High',
                              onTap: () => setState(() => _selectedLevel = 'High'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── 4. SPEED SETTING ───────────────────────────────────
                      _buildSectionHeader('SPEED SETTING'),
                      _buildSpeedCard(),

                      const SizedBox(height: 18),

                      // ── 4.5. TIMING CONFIGURATION ──────────────────────────
                      _buildSectionHeader('TIMING CONFIGURATION'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.timer_rounded, color: AppTheme.electricBlue, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Delay Between Balls',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.navyBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    '${_intervalBetweenBalls}s',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0052FF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Time interval for each delivery',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [5, 10, 15, 20, 30].map((sec) {
                                final isSelected = _intervalBetweenBalls == sec;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _intervalBetweenBalls = sec),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: isSelected ? AppTheme.primaryCtaGradient : null,
                                          color: isSelected ? null : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${sec}s',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected ? Colors.white : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            const SizedBox(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.hourglass_top_rounded, color: AppTheme.electricBlue, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Delay Between Overs',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.navyBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    '${_intervalBetweenOvers}s',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0052FF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Break time between overs',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [10, 20, 30, 45, 60].map((sec) {
                                final isSelected = _intervalBetweenOvers == sec;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _intervalBetweenOvers = sec),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: isSelected ? AppTheme.primaryCtaGradient : null,
                                          color: isSelected ? null : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${sec}s',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected ? Colors.white : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── 5. LINE / LENGTH ───────────────────────────────────
                      _buildSectionHeader('LINE / LENGTH'),
                      const Text(
                        'Line (1 - 5)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSelectableButton(
                            label: 'L1',
                            isSelected: _selectedLine == 1,
                            onTap: () => setState(() => _selectedLine = 1),
                          ),
                          const SizedBox(width: 6),
                          _buildSelectableButton(
                            label: 'L2',
                            isSelected: _selectedLine == 2,
                            onTap: () => setState(() => _selectedLine = 2),
                          ),
                          const SizedBox(width: 6),
                          _buildSelectableButton(
                            label: 'L3',
                            isSelected: _selectedLine == 3,
                            onTap: () => setState(() => _selectedLine = 3),
                          ),
                          const SizedBox(width: 6),
                          _buildSelectableButton(
                            label: 'L4',
                            isSelected: _selectedLine == 4,
                            onTap: () => setState(() => _selectedLine = 4),
                          ),
                          const SizedBox(width: 6),
                          _buildSelectableButton(
                            label: 'L5',
                            isSelected: _selectedLine == 5,
                            onTap: () => setState(() => _selectedLine = 5),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Text(
                        'Length',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSelectableButton(
                            label: 'SLOT',
                            isSelected: _selectedLength.toUpperCase() == 'SLOT',
                            onTap: () => setState(() => _selectedLength = 'SLOT'),
                          ),
                          const SizedBox(width: 8),
                          _buildSelectableButton(
                            label: 'FULL',
                            isSelected: _selectedLength.toUpperCase() == 'FULL',
                            onTap: () => setState(() => _selectedLength = 'FULL'),
                          ),
                          const SizedBox(width: 8),
                          _buildSelectableButton(
                            label: 'GOOD',
                            isSelected: _selectedLength.toUpperCase() == 'GOOD',
                            onTap: () => setState(() => _selectedLength = 'GOOD'),
                          ),
                          const SizedBox(width: 8),
                          _buildSelectableButton(
                            label: 'SHORT',
                            isSelected: _selectedLength.toUpperCase() == 'SHORT',
                            onTap: () => setState(() => _selectedLength = 'SHORT'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── 7. STEP-BY-STEP OVER CONFIGURATION & SAVE CTA ───────
                      Row(
                        children: [
                          if (_selectedOver > 1) ...[
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedOver -= 1;
                                });
                              },
                              child: Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.arrow_back_rounded, size: 18, color: AppTheme.navyBlue),
                                    SizedBox(width: 4),
                                    Text(
                                      'PREV',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.navyBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: GestureDetector(
                              onTap: _onBottomButtonPressed,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryCtaGradient,
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.electricBlue.withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _selectedOver < _totalOvers
                                              ? 'SAVE & NEXT OVER (OVER ${_selectedOver + 1})'
                                              : 'SAVE & GENERATE QR CODE',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          _selectedOver < _totalOvers
                                              ? Icons.arrow_forward_rounded
                                              : Icons.qr_code_2_rounded,
                                          color: Colors.white,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Save & Copy To All Overs shortcut
                      if (_totalOvers > 1 && _selectedOver < _totalOvers) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              if (!_validateCurrentOverConfig()) return;
                              _onCopyToAllOvers();
                              _onSave();
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.electricBlue),
                            label: Text(
                              'Save & Copy To All $_totalOvers Overs',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.electricBlue,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.navyBlue,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSelectableButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryCtaGradient : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.electricBlue.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected ? Colors.white : AppTheme.navyBlue,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('50', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                Text('70', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                Text('90', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                Text('110', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                Text('130', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                Text('150', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.electricBlue,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: AppTheme.electricBlue,
              overlayColor: AppTheme.electricBlue.withValues(alpha: 0.18),
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.5),
            ),
            child: Slider(
              value: _ballSpeed.clamp(50.0, 150.0),
              min: 50.0,
              max: 150.0,
              divisions: 10,
              onChanged: (val) => setState(() => _ballSpeed = val),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Session QR Code View & Share Dialog ─────────────────────────────────────
class SessionQrShareDialog extends StatefulWidget {
  final SessionItem? sessionItem;
  final String? sessionTitle;
  final String? sessionToken;
  final double? speed;
  final String? armType;
  final String bowlerType;
  final String length;
  final String variation;
  final String? machineId;
  final String? playerName;
  final String? playerMobile;
  final int intervalBetweenBalls;
  final int intervalBetweenOvers;
  final VoidCallback onDone;

  const SessionQrShareDialog({
    super.key,
    this.sessionItem,
    this.sessionTitle,
    this.sessionToken,
    this.speed,
    this.armType,
    this.bowlerType = 'Pace',
    this.length = 'Good',
    this.variation = 'Swing',
    this.machineId,
    this.playerName,
    this.playerMobile,
    this.intervalBetweenBalls = 5,
    this.intervalBetweenOvers = 10,
    required this.onDone,
  });

  @override
  State<SessionQrShareDialog> createState() => _SessionQrShareDialogState();
}

class _SessionQrShareDialogState extends State<SessionQrShareDialog> {
  String _resolvedPlayerName = 'Player';
  String _resolvedPlayerMobile = '9876543210';
  Timer? _pollTimer;
  bool _isScanned = false;

  void _cancelTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _resolvePlayerProfile();
    _startPollingForScan();
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  void _startPollingForScan() {
    _cancelTimer();
    // Poll every 5 seconds while QR is being shown
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _token.isEmpty || _isScanned) {
        _cancelTimer();
        return;
      }
      final isCompleted = await SessionStatusService.isSessionCompleted(_token);
      if (!mounted) {
        _cancelTimer();
        return;
      }
      if (isCompleted && !_isScanned) {
        _cancelTimer();
        setState(() => _isScanned = true);

        // Mark session as played locally if sessionItem is available
        if (widget.sessionItem != null) {
          await SessionsService().markAsPlayed(widget.sessionItem!.id);
        }

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dCtx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Session Loaded! 🏏',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your session has been successfully loaded on the bowling machine.\n\nGet ready to bat!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(dCtx);
                      },
                      child: const Text(
                        'Let\'s Play! 🏏',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          if (mounted) {
            _cancelTimer();
            widget.onDone();
          }
        }
      }
    });
  }

  Future<void> _resolvePlayerProfile() async {
    if (widget.playerName != null && widget.playerName!.isNotEmpty) {
      _resolvedPlayerName = widget.playerName!;
    }
    if (widget.playerMobile != null && widget.playerMobile!.isNotEmpty) {
      _resolvedPlayerMobile = widget.playerMobile!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final pName = prefs.getString('player_name');
      final pPhone = prefs.getString('player_phone');
      if (mounted) {
        setState(() {
          if (widget.playerName == null && pName != null && pName.isNotEmpty) {
            _resolvedPlayerName = pName;
          }
          if (widget.playerMobile == null && pPhone != null && pPhone.isNotEmpty) {
            _resolvedPlayerMobile = pPhone;
          }
        });
      }
    } catch (_) {}
  }

  String get _title => widget.sessionItem?.name ?? widget.sessionTitle ?? 'Cricket Session';
  String get _speedStr => widget.sessionItem?.speed ?? '${widget.speed?.toStringAsFixed(1) ?? '140.0'} km/h';
  String get _arm => widget.sessionItem?.armType ?? widget.armType ?? 'Right Arm';
  String get _bowler => widget.sessionItem?.bowlerType ?? widget.bowlerType;
  String get _len => widget.sessionItem?.length ?? widget.length;
  String get _var => widget.sessionItem?.variation ?? widget.variation;
  String get _code => widget.machineId ?? 'HEX-${(_title.hashCode.abs() % 9000 + 1000)}';
  String get _token => widget.sessionItem?.sessionToken ?? widget.sessionToken ?? SessionItem.generateSessionId();
  int get _ballsInterval => widget.sessionItem?.intervalBetweenBalls ?? widget.intervalBetweenBalls;
  int get _oversInterval => widget.sessionItem?.intervalBetweenOvers ?? widget.intervalBetweenOvers;

  // ── ONE6 STANDARD ENUM NORMALIZERS (Exact Match to Machine Java Backend) ───
  static String _normalizeArm(String? arm) {
    if (arm == null) return "RIGHT";
    return arm.toUpperCase().contains("LEFT") ? "LEFT" : "RIGHT";
  }

  static String _normalizeBowler(String? bType, [String? variation]) {
    if (bType == null) return "PACE";
    final upper = bType.toUpperCase();
    final upperVar = variation?.toUpperCase() ?? "";
    if (upper.contains("OFF") || upperVar.contains("OFF")) return "OFFSPIN";
    if (upper.contains("LEG") || upperVar.contains("LEG")) return "LEGSPIN";
    if (upper.contains("WRIST")) return "WRIST";
    if (upper.contains("SPIN")) {
      if (upperVar.contains("LEG")) return "LEGSPIN";
      return "OFFSPIN";
    }
    return "PACE";
  }

  static String _normalizeLength(String? len) {
    if (len == null) return "GOOD";
    final upper = len.toUpperCase();
    if (upper.contains("SLOT")) return "SLOT";
    if (upper.contains("FULL")) return "FULL";
    if (upper.contains("SHORT")) return "SHORT";
    return "GOOD";
  }

  static String? _normalizeVariation(String? bowlerType, String? variation) {
    final normBowler = _normalizeBowler(bowlerType, variation);
    if (normBowler == "PACE") {
      if (variation == null) return "SWING";
      return variation.toUpperCase().contains("SEAM") ? "SEAM" : "SWING";
    } else {
      // Spin variations: Off Spin, Leg Spin, Straight
      if (variation == null) return "STRAIGHT";
      final upper = variation.toUpperCase();
      if (upper.contains("OFF")) return "OFF_SPIN";
      if (upper.contains("LEG")) return "LEG_SPIN";
      if (upper.contains("STRAIGHT")) return "STRAIGHT";
      return upper;
    }
  }

  static String _normalizeDirection(String? dir) {
    if (dir == null) return "OUT";
    return dir.toUpperCase().contains("IN") ? "IN" : "OUT";
  }

  static String _normalizeSpinLevel(String? lvl) {
    if (lvl == null) return "BASIC";
    final upper = lvl.toUpperCase();
    if (upper.contains("ADV")) return "ADVANCE";
    if (upper.contains("MED")) return "MEDIUM";
    return "BASIC";
  }

  /// Parse numeric speed accurately (prevents "70.0 km/h" turning into 700)
  static int _parseSpeedInt(dynamic rawSpeed, [int fallback = 90]) {
    if (rawSpeed == null) return fallback;
    if (rawSpeed is num) return rawSpeed.round();
    final str = rawSpeed.toString();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(str);
    if (match != null) {
      final val = double.tryParse(match.group(1)!);
      if (val != null) {
        return val.round();
      }
    }
    return fallback;
  }

  /// ── ONE6_SESSION JSON PAYLOAD (Machine Scannable Format) ───────────────────
  String get qrDataText {
    final item = widget.sessionItem;
    final List<Map<String, dynamic>> oversPayload = [];

    if (item != null && item.overs.isNotEmpty) {
      for (int i = 0; i < item.overs.length; i++) {
        final over = item.overs[i];
        final speedInt = _parseSpeedInt(
          over['speed'],
          _parseSpeedInt(item.speed, widget.speed?.round() ?? 90),
        );

        final bowler = over['bowlerType'] ?? over['session_bowler_type'] ?? item.bowlerType;
        final arm = over['armType'] ?? over['session_arm_type'] ?? item.armType;
        final len = over['length'] ?? over['session_length'] ?? item.length;
        final variation = over['variation'] ?? over['session_variation'] ?? item.variation;
        final direction = over['direction'] ?? item.direction;
        final spinLevel = over['level'] ?? over['spin_level'] ?? item.level;

        final normArm = _normalizeArm(arm);
        final normBowler = _normalizeBowler(bowler, variation);
        final normLength = _normalizeLength(len);
        final normLine = int.tryParse((over['lineNo'] ?? over['session_line'] ?? '3').toString()) ?? 3;
        final normVariation = _normalizeVariation(bowler, variation);

        final overMap = <String, dynamic>{
          "overNumber": i + 1,
          "armType": normArm,
          "bowlerType": normBowler,
          "speed": speedInt,
          "length": normLength,
          "lineNo": normLine,
          "variation": normVariation,
          "direction": _normalizeDirection(direction),
          "spinLevel": _normalizeSpinLevel(spinLevel),
        };
        if (over['drift'] == true) overMap["drift"] = true;
        if (over['randomLength'] == true) overMap["randomLineLength"] = true;
        if (over['randomSpeed'] == true) overMap["randomSpeed"] = true;
        if (over['randomSpin'] == true) overMap["randomSpinSwing"] = true;
        oversPayload.add(overMap);
      }
    } else {
      final speedInt = widget.speed != null
          ? widget.speed!.round()
          : _parseSpeedInt(_speedStr, 90);
      final totalOversMatch = RegExp(r'\d+').firstMatch(widget.sessionItem?.oversCount ?? '');
      final totalOvers = totalOversMatch != null
          ? (int.tryParse(totalOversMatch.group(0)!) ?? 1)
          : 1;

      for (int i = 1; i <= totalOvers; i++) {
        final normArm = _normalizeArm(_arm);
        final normBowler = _normalizeBowler(_bowler, _var);
        final normLength = _normalizeLength(_len);
        final normVariation = _normalizeVariation(_bowler, _var);

        oversPayload.add({
          "overNumber": i,
          "armType": normArm,
          "bowlerType": normBowler,
          "speed": speedInt,
          "length": normLength,
          "lineNo": 3,
          "variation": normVariation,
          "direction": _normalizeDirection(widget.sessionItem?.direction ?? 'Out'),
          "spinLevel": _normalizeSpinLevel(widget.sessionItem?.level ?? 'Medium'),
        });
      }
    }

    final Map<String, dynamic> payload = {
      "type": "ONE6_SESSION",
      "version": "1.0",
      "sessionId": _token,
      "intervalBetweenBalls": _ballsInterval,
      "intervalBetweenOvers": _oversInterval,
      "player": {
        "name": _resolvedPlayerName.trim().isNotEmpty ? _resolvedPlayerName : "Player",
        "mobile": _resolvedPlayerMobile.trim().isNotEmpty ? _resolvedPlayerMobile : "9876543210",
        "batsmanType": _arm.toUpperCase().contains("LEFT") ? "Left Hand" : "Right Hand",
      },
      "session": {
        "name": _title.trim().isNotEmpty ? _title : "Practice Session",
        "oversCount": oversPayload.length,
        "intervalBetweenBalls": _ballsInterval,
        "intervalBetweenOvers": _oversInterval,
      },
      "overs": oversPayload,
    };

    return jsonEncode(payload);
  }

  void _copyShareDetails(BuildContext context) {
    Clipboard.setData(ClipboardData(text: qrDataText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'One6 Session QR data copied to clipboard!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.navyBlue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _cancelTimer();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Save Tag & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF86EFAC),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                          SizedBox(width: 5),
                          Text(
                            'SAVED IN APP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF16A34A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _cancelTimer();
                        widget.onDone();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title & Subtitle
              Text(
                _title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navyBlue,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan this QR code from the One6 bowling machine operator app to launch this practice session',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 16),

              // ── REAL SCANNABLE QR CODE CONTAINER ──────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0052FF).withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: QrImageView(
                        data: qrDataText,
                        version: QrVersions.auto,
                        size: 185.0,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                        errorStateBuilder: (ctx, err) => const SizedBox(
                          width: 185,
                          height: 185,
                          child: Center(
                            child: Text(
                              'Use Session ID below\nto load session',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Machine pairing ID tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ID: $_code • $_speedStr',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0052FF),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Tap to copy Session ID (Operator fallback for camera glare)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Session ID "$_token" copied!'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tag_rounded, size: 12, color: Color(0xFF0052FF)),
                            const SizedBox(width: 4),
                            Text(
                              'Session ID: $_token',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Live Machine Scan Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _isScanned ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isScanned ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isScanned) ...[
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                      const SizedBox(width: 6),
                      const Text(
                        'Loaded on machine! ✅',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0052FF)),
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Waiting for machine to scan...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Session Quick Spec Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildSpecChip('$_bowler • $_arm'),
                  _buildSpecChip('$_len Length'),
                  _buildSpecChip('$_var Delivery'),
                ],
              ),

              const SizedBox(height: 18),

              // ── Action Buttons: Copy Details & Done ─────────────────────────
              Row(
                children: [
                  // Copy Details / Share
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _copyShareDetails(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 1.0,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share_rounded, size: 16, color: Color(0xFF0052FF)),
                            SizedBox(width: 6),
                            Text(
                              'Share Details',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0052FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Done Button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _cancelTimer();
                        widget.onDone();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryCtaGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0052FF).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSpecChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}



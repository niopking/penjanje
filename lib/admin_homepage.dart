import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:penjanje/login.dart';
import 'auth_service.dart';

class AdminHomepage extends StatefulWidget {
  final AuthService authService;
  const AdminHomepage({super.key, required this.authService});

  @override
  State<AdminHomepage> createState() => _AdminHomepageState();
}

class _AdminHomepageState extends State<AdminHomepage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // Navigacija
  int _selectedTab = 0;

  // Korak 1: Info o takmičenju
  final _brojSmjeroviController = TextEditingController();
  final _kategorijaController = TextEditingController();
  final _trajanjController = TextEditingController();
  final _brojPokusajaController = TextEditingController();

  // Korak 2: Takmičari
  final _ukupnoController = TextEditingController();
  final _muskoController = TextEditingController();
  final _zenskoController = TextEditingController();

  List<TextEditingController> _imenaControllers = [];
  List<String> _polovi = [];

  int _currentStep = 0;
  bool _isSaving = false;

  int get _ukupno => int.tryParse(_ukupnoController.text) ?? 0;
  int get _musko => int.tryParse(_muskoController.text) ?? 0;
  int get _zensko => int.tryParse(_zenskoController.text) ?? 0;

  void _onUkupnoChanged(String val) {
    final n = int.tryParse(val) ?? 0;
    setState(() {
      final oldControllers = List<TextEditingController>.from(_imenaControllers);
      final oldPolovi = List<String>.from(_polovi);

      _imenaControllers = List.generate(n, (i) {
        return i < oldControllers.length
            ? oldControllers[i]
            : TextEditingController();
      });

      _polovi = List.generate(n, (i) {
        return i < oldPolovi.length ? oldPolovi[i] : 'M';
      });
    });
  }

  List<Map<String, dynamic>> _kreirajPrazneRezultate(
      int brojSmjerova, int brojPokusaja) {
    return List.generate(brojSmjerova, (smjerIndex) {
      return {
        'smjer': smjerIndex + 1,
        'pokusaji': [],
        'sudije' : []
      };
    });
  }

  Future<void> _spremiTakmicenje() async {
    if (!_formKey.currentState!.validate()) return;

    if (_musko + _zensko != _ukupno) {
      _showError(
          'Broj muških (${_musko}) + ženskih (${_zensko}) mora biti jednak ukupnom broju (${_ukupno}).');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final brojSmjerova = int.parse(_brojSmjeroviController.text);
      final brojPokusaja = int.parse(_brojPokusajaController.text);

      final takmicari = _imenaControllers
          .asMap()
          .entries
          .map((e) => {
                'redni_broj': e.key + 1,
                'ime': e.value.text.trim(),
                'pol': _polovi[e.key],
                'rezultati':
                    _kreirajPrazneRezultate(brojSmjerova, brojPokusaja),
              })
          .toList();

      await _firestore.collection('takmicenja').add({
        'broj_smjerova': int.parse(_brojSmjeroviController.text),
        'kategorija': _kategorijaController.text.trim(),
        'trajanje_min': int.parse(_trajanjController.text),
        'broj_pokusaja': int.parse(_brojPokusajaController.text),
        'ukupno_takmicara': _ukupno,
        'muski': _musko,
        'zenski': _zensko,
        'takmicari': takmicari,
        'kreirano': FieldValue.serverTimestamp(),
        'kreirao': widget.authService.currentUser?['username'] ?? '',
        'aktivno': false
      });

      if (!mounted) return;
      _showSuccess();
    } on FirebaseException catch (e) {
      _showError('Greška pri čuvanju: ${e.message}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), backgroundColor: const Color(0xFFB71C1C)),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF152233),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
            SizedBox(width: 10),
            Text('Uspješno!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Takmičenje je uspješno sačuvano u bazi.',
          style: TextStyle(color: Color(0xFF90CAF9)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetForma();
            },
            child: const Text('Nova forma',
                style: TextStyle(color: Color(0xFF1565C0))),
          ),
        ],
      ),
    );
  }

  void _resetForma() {
    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();
    _brojSmjeroviController.clear();
    _kategorijaController.clear();
    _trajanjController.clear();
    _brojPokusajaController.clear();
    _ukupnoController.clear();
    _muskoController.clear();
    _zenskoController.clear();
    setState(() {
      _imenaControllers = [];
      _polovi = [];
      _currentStep = 0;
    });
  }

  void _logout() {
    widget.authService.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// Prebacuje aktivno/neaktivno za dato takmičenje.
  /// Ako aktiviramo novo, prvo deaktiviramo sve ostale danas.
  Future<void> _toggleAktivno(String docId, bool trenutnoAktivno) async {
  try {
    if (!trenutnoAktivno) {
      // uzmi sva aktivna (bez datuma)
      final aktivna = await _firestore
          .collection('takmicenja')
          .where('aktivno', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final doc in aktivna.docs) {
        batch.update(doc.reference, {'aktivno': false});
      }

      batch.update(
        _firestore.collection('takmicenja').doc(docId),
        {'aktivno': true},
      );

      await batch.commit();
    } else {
      await _firestore
          .collection('takmicenja')
          .doc(docId)
          .update({'aktivno': false});
    }
  } catch (e) {
    _showError('Greška: $e');
  }
}

  @override
  void dispose() {
    _brojSmjeroviController.dispose();
    _kategorijaController.dispose();
    _trajanjController.dispose();
    _brojPokusajaController.dispose();
    _ukupnoController.dispose();
    _muskoController.dispose();
    _zenskoController.dispose();
    for (final c in _imenaControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF152233),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.terrain, color: Color(0xFF90CAF9), size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin panel',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(
                  widget.authService.currentUser?['username'] ?? '',
                  style:
                      const TextStyle(color: Color(0xFF7A9BC0), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF90CAF9)),
            tooltip: 'Odjava',
            onPressed: _logout,
          ),
        ],
      ),
      body: _selectedTab == 0 ? _buildKreiranjeTab() : _buildTakmicenjaTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        backgroundColor: const Color(0xFF152233),
        selectedItemColor: const Color(0xFF90CAF9),
        unselectedItemColor: const Color(0xFF4A6080),
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Kreiranje',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Takmičenja',
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: Kreiranje takmičenja ────────────────────────────────────────────

  Widget _buildKreiranjeTab() {
    return Form(
      key: _formKey,
      child: Stepper(
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: () {
          if (_currentStep == 0) {
            if (_brojSmjeroviController.text.isEmpty ||
                _kategorijaController.text.isEmpty ||
                _trajanjController.text.isEmpty ||
                _brojPokusajaController.text.isEmpty) {
              _showError('Popunite sva polja u prvom koraku.');
              return;
            }
            setState(() => _currentStep = 1);
          } else {
            _spremiTakmicenje();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        connectorColor:
            WidgetStateProperty.all(const Color(0xFF1565C0)),
        steps: [
          Step(
            title: const Text('Info o takmičenju',
                style: TextStyle(color: Colors.white)),
            isActive: _currentStep >= 0,
            state:
                _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildKorak1(),
          ),
          Step(
            title: const Text('Takmičari',
                style: TextStyle(color: Colors.white)),
            isActive: _currentStep >= 1,
            content: _buildKorak2(),
          ),
        ],
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _currentStep == 0 ? 'Dalje' : 'Sačuvaj',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Nazad',
                        style: TextStyle(color: Color(0xFF7A9BC0))),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── TAB 2: Prikaz takmičenja kreirana danas ────────────────────────────────

  Widget _buildTakmicenjaTab() {
    final danas = DateTime.now();
    final pocetak = DateTime(danas.year, danas.month, danas.day);
    final kraj = pocetak.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('takmicenja')
          .orderBy('kreirano', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Greška: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFFE57373))),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF90CAF9)),
          );
        }

        final sviDocs = snapshot.data?.docs ?? [];

        // Filtriranje na klijentskoj strani — izbjegava composite index
        final docs = sviDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final ts = d['kreirano'];
          if (ts == null || ts is! Timestamp) return false;
          final dt = ts.toDate();
          return dt.isAfter(pocetak) && dt.isBefore(kraj);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy,
                    color: const Color(0xFF4A6080), size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Nema takmičenja danas',
                  style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kreirajte novo takmičenje u prvom tabu.',
                  style:
                      TextStyle(color: Color(0xFF4A6080), fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final aktivno = data['aktivno'] as bool? ?? false;
            final kategorija =
                data['kategorija'] as String? ?? '—';
            final ukupno =
                data['ukupno_takmicara'] as int? ?? 0;

            return _buildTakmicenjeKartica(
              docId: doc.id,
              kategorija: kategorija,
              ukupnoTakmicara: ukupno,
              aktivno: aktivno,
            );
          },
        );
      },
    );
  }

  Widget _buildTakmicenjeKartica({
    required String docId,
    required String kategorija,
    required int ukupnoTakmicara,
    required bool aktivno,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152233),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: aktivno
              ? const Color(0xFF1565C0).withOpacity(0.8)
              : const Color(0xFF1E3A5F),
          width: aktivno ? 1.5 : 1,
        ),
        boxShadow: aktivno
            ? [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            // Ikonica statusa
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: aktivno
                    ? const Color(0xFF1565C0).withOpacity(0.15)
                    : const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                aktivno ? Icons.play_circle : Icons.pause_circle_outline,
                color: aktivno
                    ? const Color(0xFF90CAF9)
                    : const Color(0xFF4A6080),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kategorija,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.groups_outlined,
                          color: Color(0xFF7A9BC0), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$ukupnoTakmicara takmičara',
                        style: const TextStyle(
                            color: Color(0xFF7A9BC0), fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: aktivno
                              ? const Color(0xFF4CAF50).withOpacity(0.15)
                              : const Color(0xFF0D1B2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: aktivno
                                ? const Color(0xFF4CAF50).withOpacity(0.5)
                                : const Color(0xFF1E3A5F),
                          ),
                        ),
                        child: Text(
                          aktivno ? 'Aktivno' : 'Neaktivno',
                          style: TextStyle(
                            color: aktivno
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF4A6080),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Toggle dugme
            GestureDetector(
              onTap: () => _toggleAktivno(docId, aktivno),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 50,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: aktivno
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF1E3A5F),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  alignment: aktivno
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Korak 1 & 2 forme ──────────────────────────────────────────────────────

  Widget _buildKorak1() {
    return Column(
      children: [
        _buildNumberField(
          controller: _brojSmjeroviController,
          label: 'Broj smjerova',
          icon: Icons.route,
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _kategorijaController,
          label: 'Kategorija',
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: 14),
        _buildNumberField(
          controller: _trajanjController,
          label: 'Trajanje (minuta)',
          icon: Icons.timer_outlined,
        ),
        const SizedBox(height: 14),
        _buildNumberField(
          controller: _brojPokusajaController,
          label: 'Broj pokušaja po smjeru',
          icon: Icons.replay,
        ),
      ],
    );
  }

  Widget _buildKorak2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNumberField(
          controller: _ukupnoController,
          label: 'Ukupno takmičara',
          icon: Icons.groups_outlined,
          onChanged: _onUkupnoChanged,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                controller: _muskoController,
                label: 'Muških',
                icon: Icons.male,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNumberField(
                controller: _zenskoController,
                label: 'Ženskih',
                icon: Icons.female,
              ),
            ),
          ],
        ),
        if (_imenaControllers.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Imena i pol takmičara',
            style: TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ...List.generate(_imenaControllers.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildInputField(
                      controller: _imenaControllers[i],
                      label: 'Ime takmičara ${i + 1}',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFF1E3A5F)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _polovi[i],
                        dropdownColor: const Color(0xFF152233),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF7A9BC0)),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                        items: ['M', 'Ž'].map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (novo) {
                          if (novo != null)
                            setState(() => _polovi[i] = novo);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Obavezno polje' : null,
      decoration: _inputDecoration(label, icon),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white, fontSize: 15),
      onChanged: onChanged,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Obavezno polje' : null,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          const TextStyle(color: Color(0xFF7A9BC0), fontSize: 14),
      prefixIcon:
          Icon(icon, color: const Color(0xFF7A9BC0), size: 20),
      filled: true,
      fillColor: const Color(0xFF0D1B2A),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE57373))),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
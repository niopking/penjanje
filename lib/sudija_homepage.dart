import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:penjanje/login.dart';
import 'auth_service.dart';

class SudijaHomepage extends StatefulWidget {
  final AuthService authService;
  const SudijaHomepage({super.key, required this.authService});

  @override
  State<SudijaHomepage> createState() => _SudijaHomepageState();
}

class _SudijaHomepageState extends State<SudijaHomepage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF152233),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sudija Panel',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            Text('Aktivno takmičenje',
                style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF90CAF9)),
            onPressed: () {
              widget.authService.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('takmicenja')
            .where('aktivno', isEqualTo: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState('Nema aktivnih takmičenja.');
          }

          final doc = snapshot.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          final takmicenjeId = doc.id;
          final brojSmjerova = data['broj_smjerova'] ?? 0;
          final maxPokusaja = data['broj_pokusaja'] ?? 0;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: brojSmjerova,
            itemBuilder: (context, index) {
              final smjerRedniBroj = index + 1;
              return Card(
                color: const Color(0xFF152233),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1565C0),
                    child: Text('$smjerRedniBroj',
                        style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text('Smjer $smjerRedniBroj',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Klikni za unos rezultata',
                      style: TextStyle(color: Color(0xFF7A9BC0))),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Color(0xFF90CAF9), size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TakmicariListaScreen(
                          takmicenjeId: takmicenjeId,
                          smjerBroj: smjerRedniBroj,
                          maxPokusaja: maxPokusaja,
                          sudijaUsername: widget.authService.currentUser?['username'] ??
                              widget.authService.currentUser?['id'] ??
                              '',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, color: Color(0xFF7A9BC0), size: 64),
          const SizedBox(height: 16),
          Text(msg,
              style: const TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }
}

// ─── KORAK 1: Lista takmičara za odabrani smjer ──────────────────────────────

class TakmicariListaScreen extends StatelessWidget {
  final String takmicenjeId;
  final int smjerBroj;
  final int maxPokusaja;
  final String sudijaUsername;

  const TakmicariListaScreen({
    super.key,
    required this.takmicenjeId,
    required this.smjerBroj,
    required this.maxPokusaja,
    required this.sudijaUsername,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF152233),
        iconTheme: const IconThemeData(color: Color(0xFF90CAF9)),
        title: Text(
          'Smjer $smjerBroj – Takmičari',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('takmicenja')
            .doc(takmicenjeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF90CAF9)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Nema podataka.',
                    style: TextStyle(color: Colors.white)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final takmicari = (data['takmicari'] as List? ?? [])
              .map((t) => Map<String, dynamic>.from(t as Map))
              .toList();

          if (takmicari.isEmpty) {
            return const Center(
                child: Text('Nema takmičara.',
                    style: TextStyle(color: Color(0xFF7A9BC0))));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: takmicari.length,
            itemBuilder: (context, index) {
              final t = takmicari[index];
              final smjerIndex = smjerBroj - 1;

              // Izvuci pokušaje za ovaj smjer da prikažemo status
              final rezultati = (t['rezultati'] as List? ?? []);
              List<int> pokusaji = [];
              // ignore: unused_local_variable
              List<String> sudije = [];
              if (smjerIndex < rezultati.length) {
                final smjerData = Map<String, dynamic>.from(rezultati[smjerIndex] as Map);
                pokusaji = (smjerData['pokusaji'] as List? ?? [])
                    .map((p) => (p as num).toInt())
                    .toList();
                sudije = (smjerData['sudije'] as List? ?? [])  // DODAJ
                    .map((s) => s.toString())
                    .toList();
              }

              final imaTop = pokusaji.contains(3);
              final brUnesenih = pokusaji.where((p) => p != 0).length;
              final iskoristioSve =
                  maxPokusaja > 0 && brUnesenih >= maxPokusaja;
              final zavrsen = imaTop || iskoristioSve;

              return Card(
                color: const Color(0xFF152233),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: zavrsen
                        ? const Color(0xFF1E3A5F)
                        : const Color(0xFF1565C0),
                    child: Text(
                      '${t['redni_broj'] ?? index + 1}',
                      style: TextStyle(
                          color: zavrsen
                              ? const Color(0xFF4A6080)
                              : Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    '${t['ime'] ?? '—'} (${t['pol'] ?? ''})',
                    style: TextStyle(
                      color:
                          zavrsen ? const Color(0xFF4A6080) : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: _buildStatusSubtitle(
                      pokusaji, imaTop, iskoristioSve, zavrsen),
                  trailing: zavrsen
                      ? Icon(
                          imaTop ? Icons.check_circle : Icons.block,
                          color: imaTop
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE57373),
                          size: 22,
                        )
                      : const Icon(Icons.arrow_forward_ios,
                          color: Color(0xFF90CAF9), size: 16),
                  onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TakmicarDetaljiScreen(
                                takmicenjeId: takmicenjeId,
                                smjerBroj: smjerBroj,
                                takmicarIndex: index,
                                maxPokusaja: maxPokusaja,
                                sudijaId: sudijaUsername,
                              ),
                            ),
                          );
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusSubtitle(List<int> pokusaji, bool imaTop,
      bool iskoristioSve, bool zavrsen) {
    if (imaTop) {
      return const Text('TOP – unos završen',
          style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12));
    }
    if (iskoristioSve) {
      return const Text('Iskoristio sve pokušaje',
          style: TextStyle(color: Color(0xFFE57373), fontSize: 12));
    }
    final uneseno = pokusaji.where((p) => p != 0).length;
    if (uneseno == 0) {
      return const Text('Još nije počeo',
          style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 12));
    }
    return Text('$uneseno pokušaj(a) uneseno',
        style: const TextStyle(color: Color(0xFF90CAF9), fontSize: 12));
  }
}

// ─── KORAK 2: Detalji jednog takmičara – unos rezultata ─────────────────────

class TakmicarDetaljiScreen extends StatelessWidget {
  final String takmicenjeId;
  final int smjerBroj;
  final int takmicarIndex;
  final int maxPokusaja;
  final String sudijaId; // DODAJ

  const TakmicarDetaljiScreen({
    super.key,
    required this.takmicenjeId,
    required this.smjerBroj,
    required this.takmicarIndex,
    required this.maxPokusaja,
    required this.sudijaId, // DODAJ
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF152233),
        iconTheme: const IconThemeData(color: Color(0xFF90CAF9)),
        title: Text(
          'Smjer $smjerBroj – Unos rezultata',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('takmicenja')
            .doc(takmicenjeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF90CAF9)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Nema podataka.',
                    style: TextStyle(color: Colors.white)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final takmicari = (data['takmicari'] as List? ?? [])
              .map((t) => Map<String, dynamic>.from(t as Map))
              .toList();

          if (takmicarIndex >= takmicari.length) {
            return const Center(
                child: Text('Takmičar nije pronađen.',
                    style: TextStyle(color: Colors.white)));
          }

          final t = takmicari[takmicarIndex];
          final smjerIndex = smjerBroj - 1;
          final rezultati = (t['rezultati'] as List? ?? []);

          List<int> pokusaji = [];
          List<String> sudije = [];
          if (smjerIndex < rezultati.length) {
            final smjerData = Map<String, dynamic>.from(rezultati[smjerIndex] as Map);
            pokusaji = (smjerData['pokusaji'] as List? ?? [])
                .map((p) => (p as num).toInt())
                .toList();
            sudije = (smjerData['sudije'] as List? ?? [])  // DODAJ
                .map((s) => s.toString())
                .toList();
          }

          final imaTop = pokusaji.contains(3);
          final brUnesenih = pokusaji.where((p) => p != 0).length;
          final iskoristioSve =
              maxPokusaja > 0 && brUnesenih >= maxPokusaja;
          final zakljucano = imaTop || iskoristioSve;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header takmičara
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152233),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E3A5F)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text(
                          '${t['redni_broj'] ?? takmicarIndex + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['ime'] ?? '—',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Pol: ${t['pol'] ?? '—'}',
                            style: const TextStyle(
                                color: Color(0xFF7A9BC0), fontSize: 13),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (imaTop)
                        _statusBadge('TOP', const Color(0xFF4CAF50))
                      else if (iskoristioSve)
                        _statusBadge('KRAJ', const Color(0xFFE57373)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Prikaz pokušaja
                const Text(
                  'Pokušaji',
                  style: TextStyle(
                      color: Color(0xFF90CAF9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),

                // Dinamička lista – prikazuje samo unesene pokušaje
                // + prazno mjesto za sljedeći (ako ima još)
                _buildPokusajiRow(pokusaji),

                const SizedBox(height: 32),

                // ── Akcije
                if (!zakljucano) ...[
                  const Text(
                    'Označi rezultat pokušaja',
                    style: TextStyle(
                        color: Color(0xFF90CAF9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          context,
                          label: 'TOP',
                          icon: Icons.star,
                          color: const Color(0xFF388E3C),
                          vrijednost: 3,
                          pokusaji: pokusaji,
                          sudije: sudije,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          context,
                          label: 'ZONA',
                          icon: Icons.adjust,
                          color: const Color(0xFFE65100),
                          vrijednost: 2,
                          pokusaji: pokusaji,
                          sudije: sudije,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          context,
                          label: 'X',
                          icon: Icons.close,
                          color: const Color(0xFFC62828),
                          vrijednost: 1,
                          pokusaji: pokusaji,
                          sudije: sudije,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF152233),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E3A5F)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          imaTop ? Icons.check_circle : Icons.block,
                          color: imaTop
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE57373),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          imaTop
                              ? 'Takmičar je postigao TOP!'
                              : 'Iskoristio sve pokušaje.',
                          style: TextStyle(
                            color: imaTop
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE57373),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Poništi zadnji unos
                if (pokusaji.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _ponistiZadnji(context, pokusaji, sudije),
                      icon: const Icon(Icons.undo,
                          color: Color(0xFF7A9BC0), size: 18),
                      label: const Text('Poništi zadnji unos',
                          style: TextStyle(
                              color: Color(0xFF7A9BC0), fontSize: 13)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPokusajiRow(List<int> pokusaji) {
    // Prikazujemo unesene pokušaje + jedno prazno polje ako još ima mjesta
    final prikazani = List<int>.from(pokusaji.where((p) => p != 0));
    final imaJos =
        maxPokusaja == 0 || prikazani.length < maxPokusaja;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...prikazani.asMap().entries.map((e) => _pokusajTile(e.key, e.value)),
        if (imaJos)
          _pokusajTile(prikazani.length, 0, isSledeci: true),
      ],
    );
  }

  Widget _pokusajTile(int index, int status, {bool isSledeci = false}) {
    Color bg;
    String label;
    IconData? icon;

    switch (status) {
      case 3:
        bg = const Color(0xFF388E3C).withOpacity(0.85);
        label = 'T';
        icon = Icons.star;
        break;
      case 2:
        bg = const Color(0xFFE65100).withOpacity(0.85);
        label = 'Z';
        icon = Icons.adjust;
        break;
      case 1:
        bg = const Color(0xFFC62828).withOpacity(0.85);
        label = 'X';
        icon = Icons.close;
        break;
      default:
        bg = isSledeci
            ? const Color(0xFF1565C0).withOpacity(0.15)
            : const Color(0xFF1E3A5F);
        label = '${index + 1}';
        icon = null;
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSledeci
              ? const Color(0xFF1565C0).withOpacity(0.6)
              : const Color(0xFF415A77),
          width: isSledeci ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, color: Colors.white, size: 18)
          else
            Text(
              label,
              style: TextStyle(
                color: isSledeci
                    ? const Color(0xFF90CAF9)
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          Text(
            '${index + 1}.',
            style: TextStyle(
                color: isSledeci
                    ? const Color(0xFF4A6080)
                    : Colors.white54,
                fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required int vrijednost,
    required List<int> pokusaji,
    required List<String> sudije,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      onPressed: () => _unesiRezultat(context, vrijednost, pokusaji, sudije),
    );
  }

  Future<void> _unesiRezultat(
      BuildContext context, int vrijednost, List<int> trenutniPokusaji,
      List<String> trenutneSudije) async {
    final noviPokusaji = List<int>.from(trenutniPokusaji)..add(vrijednost);
    final noveSudije = List<String>.from(trenutneSudije)..add(sudijaId);
    await _sacuvaj(context, noviPokusaji, noveSudije);
  }

  Future<void> _ponistiZadnji(
      BuildContext context, List<int> trenutniPokusaji,
      List<String> trenutneSudije) async {
    if (trenutniPokusaji.isEmpty) return;
    final noviPokusaji = List<int>.from(trenutniPokusaji)..removeLast();
    final noveSudije = List<String>.from(trenutneSudije)..removeLast();
    await _sacuvaj(context, noviPokusaji, noveSudije);
  }

  Future<void> _sacuvaj(
      BuildContext context, List<int> noviPokusaji,
      List<String> noveSudije) async {
    final smjerIndex = smjerBroj - 1;
    final docRef = FirebaseFirestore.instance
        .collection('takmicenja')
        .doc(takmicenjeId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return;

        final data = Map<String, dynamic>.from(snap.data() as Map);
        final takmicari = (data['takmicari'] as List)
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();

        final rezultati = (takmicari[takmicarIndex]['rezultati'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        rezultati[smjerIndex] = {
          'smjer': rezultati[smjerIndex]['smjer'],
          'pokusaji': noviPokusaji,
          'sudije': noveSudije, // DODAJ
        };

        takmicari[takmicarIndex] = Map<String, dynamic>.from(
            takmicari[takmicarIndex])
          ..['rezultati'] = rezultati;

        transaction.update(docRef, {'takmicari': takmicari});
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri čuvanju: $e'),
            backgroundColor: const Color(0xFFB71C1C),
          ),
        );
      }
    }
  }
}

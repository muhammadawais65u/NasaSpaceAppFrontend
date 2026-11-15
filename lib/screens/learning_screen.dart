import 'package:flutter/material.dart';

import '../models.dart';
import '../services/game_controller.dart';
import '../widgets/ui.dart';

class _Topic {
  const _Topic(this.title, this.icon, this.image, this.facts);

  final String title;
  final IconData icon;
  final String? image;
  final List<String> facts;
}

const List<_Topic> _topics = [
  _Topic('Moon Facts', Icons.brightness_2, 'assets/images/moon.jpg', [
    'The Moon is Earth\'s closest neighbor and has no air to breathe.',
    'The Moon is about 384,000 kilometres from Earth.',
    'Gravity on the Moon is about one sixth of Earth\'s. You could jump much higher there!',
    'A day on the Moon lasts about two Earth weeks. So does the night.',
    'There is water ice inside dark, cold craters near the Moon\'s poles.',
  ]),
  _Topic('Space Safety', Icons.shield, 'assets/images/sun.jpg', [
    'Earth\'s air and magnetic field block most space radiation. The Moon has no shield like that.',
    'A solar flare is a sudden, bright burst of energy from the Sun.',
    'A coronal mass ejection (CME) is a giant cloud of hot gas thrown out by the Sun.',
    'A geomagnetic storm happens when the Sun\'s material shakes Earth\'s magnetic field.',
    'During a solar storm, astronauts shelter behind thick walls, water tanks or Moon soil.',
  ]),
  _Topic('Astronaut Life', Icons.person, null, [
    'On the International Space Station most water is recycled. Even sweat is cleaned into drinking water!',
    'Astronauts exercise about two hours every day to keep their bones and muscles strong.',
    'Astronauts have grown lettuce and other plants on the Space Station.',
    'A radio message takes a little more than one second to travel between the Moon and Earth.',
  ]),
];

const List<String> _researchTopics = ['radiation', 'bone', 'muscle', 'plants', 'sleep'];

/// Simple facts plus two live NASA sources: DONKI (space weather) and OSDR (research).
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  static const int _weatherTab = 3;
  static const int _researchTab = 4;

  int _tab = 0;
  String _term = _researchTopics.first;
  Future<ResearchResult>? _research;

  void _select(int tab) {
    final game = GameScope.of(context);
    setState(() {
      _tab = tab;
      if (tab == _researchTab) _research ??= game.api.research(_term);
    });
    if (tab == _weatherTab && game.weather == null) game.refreshWeather();
  }

  void _search(String term) {
    final game = GameScope.of(context);
    setState(() {
      _term = term;
      _research = game.api.research(term);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final titles = [for (final t in _topics) t.title, 'Space Weather Now', 'NASA Research'];
    final icons = [for (final t in _topics) t.icon, Icons.wb_sunny_rounded, Icons.science];

    Widget menuButton(int i) {
      final selected = i == _tab;
      return Semantics(
        selected: selected,
        child: GameButton(
          label: titles[i],
          icon: icons[i],
          color: selected ? GameColors.yellow : GameColors.blue,
          onPressed: () => _select(i),
        ),
      );
    }

    final Widget content;
    if (_tab == _weatherTab) {
      content = _weather(game);
    } else if (_tab == _researchTab) {
      content = _researchView();
    } else {
      content = _facts(_topics[_tab], game.astronaut);
    }

    return SpaceBackground(
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                  icon: Icons.arrow_back, tooltip: 'Back', onPressed: () => Navigator.of(context).pop()),
              const Expanded(child: Center(child: TitleBanner('Learning Center'))),
              const SizedBox(width: 46),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final panel = GlassPanel(child: content);
                if (box.maxWidth >= 720) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 250,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < titles.length; i++)
                                Padding(padding: const EdgeInsets.only(bottom: 10), child: menuButton(i)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: SizedBox(height: box.maxHeight, child: panel)),
                    ],
                  );
                }
                return Column(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [for (var i = 0; i < titles.length; i++) menuButton(i)],
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: panel),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _facts(_Topic topic, String astronaut) {
    return ListView(
      children: [
        Center(
          child: topic.image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(topic.image!, height: 140, fit: BoxFit.cover, semanticLabel: topic.title),
                )
              : AstronautAvatar(id: astronaut, size: 110),
        ),
        const SizedBox(height: 10),
        for (final fact in topic.facts) _FactRow(text: fact),
      ],
    );
  }

  Widget _weather(GameController game) {
    final w = game.weather;
    if (w == null) {
      return Center(
        child: game.weatherLoading
            ? const CircularProgressIndicator(color: GameColors.yellow)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      game.signedIn
                          ? 'NASA data is not available right now.'
                          : 'Press Start Mission and type your name to see live NASA data.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 10),
                  if (game.signedIn)
                    GameButton(label: 'Try Again', icon: Icons.refresh, onPressed: game.refreshWeather),
                ],
              ),
      );
    }
    final events = w.events.length > 15 ? w.events.sublist(0, 15) : w.events;
    return ListView(
      children: [
        const Text('What the Sun did in the last 7 days',
            style: TextStyle(color: GameColors.yellow, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        DataBadge(status: w.dataStatus, source: 'NASA DONKI', retrievedAt: w.retrievedAt),
        const SizedBox(height: 6),
        Text(
          'These are real reports from NASA\'s space weather database. '
          'In our game they set the alert to ${w.alertLevel.toUpperCase()}. '
          'The alert is part of the game, not a NASA measurement.',
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('No solar events were reported in this time.',
              style: TextStyle(color: GameColors.textDim, fontSize: 15)),
        for (final e in events) _EventRow(event: e),
        const SizedBox(height: 8),
        const Text('Source: NASA DONKI (Space Weather Database Of Notifications, Knowledge, Information).',
            style: TextStyle(color: GameColors.textDim, fontSize: 12)),
      ],
    );
  }

  Widget _researchView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Real NASA studies about living in space',
            style: TextStyle(color: GameColors.yellow, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _researchTopics)
              ChoiceChip(label: Text(t), selected: t == _term, onSelected: (_) => _search(t)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<ResearchResult>(
            future: _research,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: GameColors.yellow));
              }
              final data = snap.data;
              if (data == null) {
                return Center(
                  child: Text(
                      GameScope.of(context).signedIn
                          ? 'NASA research data is not available right now.'
                          : 'Press Start Mission and type your name to see NASA research.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                );
              }
              return ListView(
                children: [
                  DataBadge(status: data.dataStatus, source: 'NASA OSDR'),
                  if (data.totalMatches != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('NASA has ${data.totalMatches} studies that mention "$_term".',
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  const SizedBox(height: 6),
                  for (final s in data.studies) _StudyCard(study: s),
                  const Text('Source: NASA Open Science Data Repository (OSDR). Written for scientists, '
                      'so ask a grown-up to help you read them!',
                      style: TextStyle(color: GameColors.textDim, fontSize: 12)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: GameColors.yellow, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.3))),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final SpaceEvent event;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String meaning;
    switch (event.type) {
      case 'GST':
        icon = Icons.public;
        color = GameColors.red;
        meaning = 'Earth\'s magnetic field was shaken.';
        break;
      case 'FLR':
        icon = Icons.flash_on;
        color = GameColors.yellow;
        meaning = 'A sudden burst of energy from the Sun.';
        break;
      default:
        icon = Icons.cloud;
        color = const Color(0xFFFF9F45);
        meaning = 'A giant cloud of gas left the Sun.';
    }
    final extra = <String>[];
    final speed = event.details['speed_km_s'];
    if (speed is num) extra.add('Speed: ${speed.round()} km per second');
    final kp = event.details['max_kp_index'];
    if (kp is num) extra.add('Kp index: $kp');
    final date = event.date;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${event.title}${date == null ? '' : ' - ${formatDate(date)}'}',
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
                Text([meaning, ...extra].join('  '), style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.study});

  final Study study;

  @override
  Widget build(BuildContext context) {
    final description = study.description;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1238),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameColors.panelBorder.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(study.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          if (study.organism != null)
            Text('Studied: ${study.organism}', style: const TextStyle(color: GameColors.yellow, fontSize: 13)),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: GameColors.textDim, fontSize: 13, height: 1.25)),
            ),
          const SizedBox(height: 4),
          SelectableText('${study.accession}  ${study.link}',
              style: const TextStyle(color: GameColors.panelBorder, fontSize: 12)),
        ],
      ),
    );
  }
}

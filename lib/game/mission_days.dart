import 'package:flutter/material.dart';

/// How the astronaut interacts with one objective pad. Each kind gets its
/// own pad icon, verb and built structure in the scene.
enum InteractKind { explore, collect, scan, repair, install, activate, build }

extension InteractKindX on InteractKind {
  String get verb => const {
        InteractKind.explore: 'Explore',
        InteractKind.collect: 'Collect',
        InteractKind.scan: 'Scan',
        InteractKind.repair: 'Repair',
        InteractKind.install: 'Install',
        InteractKind.activate: 'Activate',
        InteractKind.build: 'Build',
      }[this]!;

  String get doing => const {
        InteractKind.explore: 'Exploring...',
        InteractKind.collect: 'Collecting...',
        InteractKind.scan: 'Scanning...',
        InteractKind.repair: 'Repairing...',
        InteractKind.install: 'Installing...',
        InteractKind.activate: 'Activating...',
        InteractKind.build: 'Building...',
      }[this]!;

  IconData get icon => const {
        InteractKind.explore: Icons.explore_rounded,
        InteractKind.collect: Icons.backpack_rounded,
        InteractKind.scan: Icons.radar_rounded,
        InteractKind.repair: Icons.build_rounded,
        InteractKind.install: Icons.bolt_rounded,
        InteractKind.activate: Icons.power_settings_new_rounded,
        InteractKind.build: Icons.construction_rounded,
      }[this]!;

  /// Colony resources this action uses up (positive numbers = consumed).
  Map<String, int> get cost => const {
        InteractKind.explore: {'oxygen_level': 3, 'food_level': 1},
        InteractKind.collect: {'oxygen_level': 2, 'food_level': 2},
        InteractKind.scan: {'power_level': 3},
        InteractKind.repair: {'power_level': 6, 'oxygen_level': 3},
        InteractKind.install: {'power_level': 6, 'oxygen_level': 2},
        InteractKind.activate: {'power_level': 5},
        InteractKind.build: {
          'oxygen_level': 5,
          'power_level': 8,
          'water_level': 5,
          'food_level': 3,
          'radiation_protection_level': 2,
        },
      }[this]!;

  /// Why this action uses those resources, shown under the cost chips.
  String get costReason => const {
        InteractKind.explore: 'Walking far burns suit oxygen and energy snacks.',
        InteractKind.collect: 'Digging and hauling rocks uses oxygen and food energy.',
        InteractKind.scan: 'The scanner runs on suit battery power.',
        InteractKind.repair: 'Welding tools draw power and the hard work uses oxygen.',
        InteractKind.install: 'Bolting in equipment uses power and suit oxygen.',
        InteractKind.activate: 'Switching a system on draws colony power.',
        InteractKind.build: 'Construction needs tools (power), crew air (oxygen), water, food and shield material.',
      }[this]!;

  /// What the action teaches the player, shown in a pop-up after it finishes.
  String get lesson => const {
        InteractKind.explore:
            'Astronauts explore to map the ground first. They look for flat, safe spots away from deep craters before anyone builds. A good spot keeps the whole colony safe!',
        InteractKind.collect:
            'Nothing is wasted on the Moon! Collected rocks, ice and parts all get reused - ice becomes water and oxygen, and spare parts fix broken machines.',
        InteractKind.scan:
            'Scanning measures what you cannot see - radiation above ground and ice below it. Astronauts always scan before they dig, so nobody walks into danger.',
        InteractKind.repair:
            'Small breaks become big disasters fast in space. A tiny hole can drain all the oxygen out! Quick repairs keep the crew breathing and the colony alive.',
        InteractKind.install:
            'Installing connects new equipment to the colony - cables carry power, pipes carry water, and computers tell the machine what to do.',
        InteractKind.activate:
            'Switching a system on brings it to life! Solar panels start making energy, shields start blocking radiation, and filters start cleaning the air.',
        InteractKind.build:
            'Every structure you build keeps the crew alive longer - a habitat gives shelter, a greenhouse gives food, and a workshop gives tools. Building is how a camp becomes a colony!',
      }[this]!;
}

/// Story, environment and interaction flavour for one mission day.
class DayTheme {
  const DayTheme({
    required this.tagline,
    required this.story,
    required this.environment,
    required this.ending,
    required this.accent,
    required this.kinds,
  });

  /// Short theme line shown under the mission title.
  final String tagline;

  /// Cinematic story shown on the briefing screen.
  final String story;

  /// What the player sees in the world, shown on the briefing screen.
  final String environment;

  /// Last line of the mission-ending cinematic.
  final String ending;

  /// Colour used for the day's pads, panels and glow.
  final Color accent;

  /// One interaction kind per objective (same order as the backend list).
  final List<InteractKind> kinds;

  InteractKind kindOf(int i) => i < kinds.length ? kinds[i] : InteractKind.build;
}

const Map<int, DayTheme> dayThemes = {
  1: DayTheme(
    tagline: 'Build Your First Home',
    story:
        'The astronaut lands on the Moon and must establish a safe lunar colony before the essential supplies run out.',
    environment: 'Bright lunar landscape, landing spacecraft, rocks, craters and Earth in the sky.',
    ending: 'The habitat is complete. The colony has a first home!',
    accent: Color(0xFF34C759),
    kinds: [InteractKind.explore, InteractKind.build, InteractKind.install],
  ),
  2: DayTheme(
    tagline: "Restore the Colony's Energy",
    story:
        "The colony's power supply is becoming unstable. The astronaut must restore solar energy and prevent a complete power failure.",
    environment: 'Solar panel field, energy equipment, battery stations and glowing power lines.',
    ending: 'The solar panels are online - the colony lights are back on!',
    accent: Color(0xFFFFD35E),
    kinds: [InteractKind.activate, InteractKind.install, InteractKind.scan],
  ),
  3: DayTheme(
    tagline: 'Survive the Solar Storm',
    story:
        'Mission Control detects a dangerous radiation burst approaching the Moon. The astronaut must protect the colony and reach safety.',
    environment: 'Dramatic lunar sky, solar radiation glow and emergency warning lights.',
    ending: 'The radiation shield is up. The colony is safe from the storm!',
    accent: Color(0xFF8E5BFF),
    kinds: [InteractKind.scan, InteractKind.activate, InteractKind.explore],
  ),
  4: DayTheme(
    tagline: 'Discover Hidden Water',
    story:
        "The colony's water supply is almost exhausted. The astronaut must find hidden ice and restore the life-support system.",
    environment: 'Ice-covered craters, blue glowing crystals and water extraction gear.',
    ending: 'Water is flowing into the colony storage tanks!',
    accent: Color(0xFF42A5F5),
    kinds: [InteractKind.activate, InteractKind.scan, InteractKind.repair],
  ),
  5: DayTheme(
    tagline: 'Save the Colony',
    story:
        'A meteorite strikes near the lunar habitat, damaging critical systems and causing an oxygen leak. The astronaut must act quickly!',
    environment: 'Meteorite crater, smoke and debris, damaged habitat and red emergency lighting.',
    ending: 'The habitat is repaired and oxygen is flowing again!',
    accent: Color(0xFFFF4D5A),
    kinds: [InteractKind.repair, InteractKind.activate, InteractKind.explore],
  ),
  6: DayTheme(
    tagline: 'Grow Food on the Moon',
    story:
        "The colony's food supplies are running low. The astronaut must build a greenhouse and grow fresh food.",
    environment: 'Futuristic greenhouse, hydroponic farming and growing vegetables.',
    ending: 'A successful harvest! The greenhouse is up and running!',
    accent: Color(0xFF66BB6A),
    kinds: [InteractKind.build, InteractKind.install, InteractKind.collect],
  ),
  7: DayTheme(
    tagline: 'Discover the Secrets of the Moon',
    story:
        'The colony is stable. Mission Control gives the astronaut one final mission: explore unknown craters and send the discoveries back to Earth.',
    environment: 'Deep craters, mysterious rocks, science gear and a beautiful view of Earth.',
    ending: 'The research data has been transmitted to Earth!',
    accent: Color(0xFF45E6FF),
    kinds: [InteractKind.explore, InteractKind.collect, InteractKind.activate],
  ),
};

/// The day theme, with a safe fallback.
DayTheme themeForDay(int day) => dayThemes[day] ?? dayThemes[7]!;

/// Suit accent colour per astronaut id, shown in the game scene.
Color suitAccentFor(String astronautId) => const {
      'alex': Color(0xFF45E6FF),
      'emma': Color(0xFF8E5BFF),
      'noah': Color(0xFFFFAA33),
    }[astronautId] ??
    const Color(0xFF45E6FF);

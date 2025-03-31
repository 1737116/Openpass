import 'dart:math';

class VaultIcons {
  static const List<String> vaultIconOptions = [
    'emojione-v1--alarm-clock.svg',
    'emojione-v1--alien.svg',
    'emojione-v1--american-football.svg',
    'emojione-v1--articulated-lorry.svg',
    'emojione-v1--baby-angel.svg',
    'emojione-v1--baby-bottle.svg',
    'emojione-v1--baby-chick.svg',
    'emojione-v1--baby-symbol.svg',
    'emojione-v1--baby.svg',
    'emojione-v1--balloon.svg',
    'emojione-v1--barber-pole.svg',
    'emojione-v1--baseball.svg',
    'emojione-v1--basketball.svg',
    'emojione-v1--beach-with-umbrella.svg',
    'emojione-v1--beaming-face-with-smiling-eyes.svg',
    'emojione-v1--black-nib.svg',
    'emojione-v1--bookmark-tabs.svg',
    'emojione-v1--books.svg',
    'emojione-v1--bouquet-of-flowers.svg',
    'emojione-v1--bouquet.svg',
    'emojione-v1--bug.svg',
    'emojione-v1--candy.svg',
    'emojione-v1--card-index-dividers.svg',
    'emojione-v1--card-index.svg',
    'emojione-v1--carousel-horse.svg',
    'emojione-v1--carp-streamer.svg',
    'emojione-v1--cat-face.svg',
    'emojione-v1--cat.svg',
    'emojione-v1--chipmunk.svg',
    'emojione-v1--christmas-tree.svg',
    'emojione-v1--circus-tent.svg',
    'emojione-v1--cityscape-at-dusk.svg',
    'emojione-v1--cityscape.svg',
    'emojione-v1--clutch-bag.svg',
    'emojione-v1--couch-and-lamp.svg',
    'emojione-v1--custard.svg',
    'emojione-v1--deciduous-tree.svg',
    'emojione-v1--desert.svg',
    'emojione-v1--door.svg',
    'emojione-v1--dotted-six-pointed-star.svg',
    'emojione-v1--euro-banknote.svg',
    'emojione-v1--ewe.svg',
    'emojione-v1--ferris-wheel.svg',
    'emojione-v1--fireworks.svg',
    'emojione-v1--fish-cake-with-swirl.svg',
    'emojione-v1--fish.svg',
  ];

  static String checkIcon(String icon) {
    if (vaultIconOptions.contains(icon)) {
      return icon;
    } else {
      return vaultIconOptions[0];
    }
  }

  static String getRandomIcon() {
    final random = Random();
    return vaultIconOptions[random.nextInt(vaultIconOptions.length)];
  }
}
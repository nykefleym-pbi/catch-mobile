import 'package:flutter/material.dart';

/// Central registry for the illustrated art set (organised on disk under
/// `assets/art/{UI,Camera Type,Cat Items}/`). Every asset the app ships is named
/// here exactly once, so a screen references a constant instead of a stringly
/// path — a typo becomes a compile error, and the optimisation/renaming of an
/// asset is a one-line change here rather than a hunt across the codebase.
///
/// The source art is 512² webp with alpha; the build step downscales UI icons to
/// 128² and item/camera art to 256² and re-encodes (~66% smaller) so first paint
/// and scrolling stay cheap. Render everything through [AppAssetImage], which
/// decodes at the display size ([cacheWidth]) rather than full resolution.
class AppAssets {
  const AppAssets._();

  static const _ui = 'assets/art/UI';
  static const _cam = 'assets/art/Camera Type';
  static const _items = 'assets/art/Cat Items';

  // --- UI iconography (the 12 interface marks) ---------------------------
  static const paw = '$_ui/Paws.webp';
  static const catStory = '$_ui/Cat Story.webp';
  static const guardian = '$_ui/Guardian.webp';
  static const catDex = '$_ui/Cat Dex.webp';
  static const ticket = '$_ui/Ticket.webp';
  static const diamond = '$_ui/Diamond.webp';
  static const gift = '$_ui/Gift.webp';
  static const heart = '$_ui/Heart.webp';
  static const star = '$_ui/Star.webp';
  static const experience = '$_ui/Experience.webp';
  static const coin = '$_ui/Coin.webp';
  static const map = '$_ui/Map.webp';

  // --- Camera Type (capture-flow camera art) -----------------------------
  static const cameras = <String>[
    '$_cam/Camera 1.webp',
    '$_cam/Camera 2.webp',
    '$_cam/Camera 3.webp',
    '$_cam/Camera 4.webp',
    '$_cam/Camera 5.webp',
    '$_cam/Camera 6.webp',
    '$_cam/Camera 7.webp',
  ];

  // --- Cat Items (food, toys, grooming, furniture, carriers) -------------
  // Keyed by a stable slug so gameplay catalogues (treats, decor, grooming)
  // can look an asset up by id without knowing the on-disk filename.
  static const Map<String, String> items = {
    'automatic_feeder': '$_items/Automatic Feeder.webp',
    'automatic_litter_machine': '$_items/Automatic Litter Machine.webp',
    'ball_of_yarn': '$_items/Ball of Yarn.webp',
    'cage': '$_items/Cage.webp',
    'canned_food': '$_items/Canned Food.webp',
    'cat_bed': '$_items/Cat Bed.webp',
    'cat_grass': '$_items/Cat Grass.webp',
    'cat_house': '$_items/Cat House.webp',
    'cat_tree': '$_items/Cat Tree.webp',
    'cat_tunnel': '$_items/Cat Tunnel.webp',
    'catnip': '$_items/Catnip.webp',
    'cone_of_shame': '$_items/Cone of Shame.webp',
    'discarded_box': '$_items/Discarded Box.webp',
    'egg': '$_items/Egg.webp',
    'feather_teaser': '$_items/Feather Teaser.webp',
    'fish': '$_items/Fish.webp',
    'food_bowl': '$_items/Food Bowl.webp',
    'hanging_hammock': '$_items/Hanging Hammock.webp',
    'kibbles': '$_items/Kibbles.webp',
    'laser_pointer': '$_items/Laser Pointer.webp',
    'litter_box': '$_items/Litter Box.webp',
    'litter_sand': '$_items/Litter Sand.webp',
    'medicine': '$_items/Medicine.webp',
    'milk': '$_items/Milk.webp',
    'nail_clipper': '$_items/Nail Clipper.webp',
    'nail_file': '$_items/Nail File.webp',
    'pet_carrier': '$_items/Pet Carrier.webp',
    'pet_carrier_backpack': '$_items/Pet Carrier - Back Pack.webp',
    'pet_carrier_travel_bag': '$_items/Pet Carrier - Travel Bag.webp',
    'pet_stroller': '$_items/Pet Stroller.webp',
    'plushie': '$_items/Plushie.webp',
    'scratch_pad': '$_items/Scratch Pad.webp',
    'scratch_post': '$_items/Scratch Post.webp',
    'shampoo': '$_items/Shampoo.webp',
    'shaver': '$_items/Shaver.webp',
    'soap': '$_items/Soap.webp',
    'steamed_carrot_and_squash': '$_items/Steamed Carrot and Squash.webp',
    'toothbrush': '$_items/Toothbrush.webp',
    'toy_mouse': '$_items/Toy Mouse.webp',
    'treadmill': '$_items/Treadmill.webp',
    'treats': '$_items/Treats.webp',
    'vitamins': '$_items/Vitamins.webp',
    'water_fountain': '$_items/Water Fountain.webp',
  };

  /// Look up a Cat Item asset path by slug, or null when there is no art.
  static String? item(String slug) => items[slug];

  /// A single representative camera for the capture flow's warm-up art.
  static const cameraArt = '$_cam/Camera 1.webp';

  // --- Cat Item convenience getters (the ones wired into gameplay) --------
  static const kibbles = '$_items/Kibbles.webp';
  static const fish = '$_items/Fish.webp';
  static const cannedFood = '$_items/Canned Food.webp';
  static const catnip = '$_items/Catnip.webp';
  static const treats = '$_items/Treats.webp';
  static const catBed = '$_items/Cat Bed.webp';
  static const foodBowl = '$_items/Food Bowl.webp';
  static const catGrass = '$_items/Cat Grass.webp';
  static const ballOfYarn = '$_items/Ball of Yarn.webp';
  static const catTree = '$_items/Cat Tree.webp';
  static const scratchPost = '$_items/Scratch Post.webp';
  static const catHouse = '$_items/Cat House.webp';
  static const hangingHammock = '$_items/Hanging Hammock.webp';
  static const catTunnel = '$_items/Cat Tunnel.webp';
  static const waterFountain = '$_items/Water Fountain.webp';
  static const shampoo = '$_items/Shampoo.webp';
  static const soap = '$_items/Soap.webp';
  static const nailClipper = '$_items/Nail Clipper.webp';
  static const toothbrush = '$_items/Toothbrush.webp';
}

/// Renders an [AppAssets] path at a sensible decode resolution. Passing [size]
/// sets both the layout box and the decode cache width (times the device pixel
/// ratio), so a 256² source drawn at 32px is decoded to ~32px — not held in
/// memory at full size. Falls back to a soft paw glyph if an asset is missing.
class AppAssetImage extends StatelessWidget {
  const AppAssetImage(
    this.asset, {
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    super.key,
  });

  final String asset;
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheW = w == null ? null : (w * dpr).round();
    return Image.asset(
      asset,
      width: w,
      height: h,
      fit: fit,
      cacheWidth: cacheW,
      semanticLabel: semanticLabel,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, _, __) => Icon(Icons.pets, size: w),
    );
  }
}

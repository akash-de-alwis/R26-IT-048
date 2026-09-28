/// Which box dimension is used to estimate distance: HEIGHT for upright
/// things (people, animals, bicycles), WIDTH for vehicles.
enum Dim { width, height }

class ObjectProfile {
  final Dim dim;
  final double meters; // real-world size along [dim]
  final bool vulnerable;
  final String group;

  const ObjectProfile(this.dim, this.meters,
      {this.vulnerable = false, required this.group});
}

/// COCO labels with a known real-world size. Any other label is treated as
/// a generic obstacle (no distance, see classifyGenericObstacle).
const Map<String, ObjectProfile> objectProfiles = {
  'person': ObjectProfile(Dim.height, 1.7, vulnerable: true, group: 'person'),
  'bicycle': ObjectProfile(Dim.height, 1.1, vulnerable: true, group: 'cyclist'),
  'motorcycle':
      ObjectProfile(Dim.width, 0.8, vulnerable: true, group: 'motorcycle'),
  'car': ObjectProfile(Dim.width, 1.8, group: 'vehicle'),
  'bus': ObjectProfile(Dim.width, 2.5, group: 'bus'),
  'truck': ObjectProfile(Dim.width, 2.4, group: 'truck'),
  'dog': ObjectProfile(Dim.height, 0.55, vulnerable: true, group: 'animal'),
  'cat': ObjectProfile(Dim.height, 0.30, vulnerable: true, group: 'animal'),
  'horse': ObjectProfile(Dim.height, 1.6, vulnerable: true, group: 'animal'),
  'cow': ObjectProfile(Dim.height, 1.4, vulnerable: true, group: 'animal'),
  'sheep': ObjectProfile(Dim.height, 0.8, vulnerable: true, group: 'animal'),
};

/// Vehicle labels only count when they are in the driving path.
const Set<String> vehicleLabels = {'car', 'bus', 'truck', 'motorcycle'};

const String genericObstacleGroup = 'obstacle';

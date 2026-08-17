import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/explore_entity_picker/explore_entity_picker_config.dart';

void main() {
  test('trimmedLinkedSpotListName ignores blank list names', () {
    expect(
      const ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.eventWhere,
        linkedSpotListName: '  My Random List  ',
      ).trimmedLinkedSpotListName,
      'My Random List',
    );
    expect(
      const ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.eventWhere,
        linkedSpotListName: '   ',
      ).trimmedLinkedSpotListName,
      isNull,
    );
  });
}

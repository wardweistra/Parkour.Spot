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

  test('isMultiSpotSelection is spotsOnly plus allowMultipleSpots', () {
    expect(
      const ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.spotsOnly,
        allowMultipleSpots: true,
      ).isMultiSpotSelection,
      isTrue,
    );
    expect(
      const ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.spotsOnly,
      ).isMultiSpotSelection,
      isFalse,
    );
    expect(
      const ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.eventWhere,
        allowMultipleSpots: true,
      ).isMultiSpotSelection,
      isFalse,
    );
  });
}

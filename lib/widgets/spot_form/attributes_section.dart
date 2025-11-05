import 'package:flutter/material.dart';
import '../../constants/spot_attributes.dart';

class SpotAttributesSection extends StatelessWidget {
  final String? selectedAccess;
  final Set<String> selectedFeatures;
  final Map<String, String> selectedFacilities;
  final Set<String> selectedGoodFor;
  final void Function(String?) onAccessChanged;
  final void Function(String key, bool selected) onToggleFeature;
  final void Function(String key, String value) onFacilityChanged;
  final void Function(String key, bool selected) onToggleGoodFor;

  const SpotAttributesSection({
    super.key,
    required this.selectedAccess,
    required this.selectedFeatures,
    required this.selectedFacilities,
    required this.selectedGoodFor,
    required this.onAccessChanged,
    required this.onToggleFeature,
    required this.onFacilityChanged,
    required this.onToggleGoodFor,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildGoodForCard(context, isWide: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildFeaturesCard(context, isWide: true)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAccessCard(context, isWide: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildFacilitiesCard(context, isWide: true)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGoodForCard(context, isWide: false),
        const SizedBox(height: 16),
        _buildFeaturesCard(context, isWide: false),
        const SizedBox(height: 16),
        _buildAccessCard(context, isWide: false),
        const SizedBox(height: 16),
        _buildFacilitiesCard(context, isWide: false),
      ],
    );
  }

  Widget _buildGoodForCard(BuildContext context, {required bool isWide}) {
    final wrapContent = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SpotAttributes.getKeys('goodFor').map((key) {
                  final label = SpotAttributes.getLabel('goodFor', key);
                  final icon = SpotAttributes.getIcon('goodFor', key);
                  final description = SpotAttributes.getDescription('goodFor', key);
                  final selected = selectedGoodFor.contains(key);
                  return Tooltip(
                    message: description,
                    child: GestureDetector(
                      onTap: () => onToggleGoodFor(key, !selected),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected 
                              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected 
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon, 
                              size: 16, 
                              color: selected 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: selected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good For',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'What parkour skills can be practiced here?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 12),
            if (isWide)
              Expanded(
                child: SingleChildScrollView(child: wrapContent),
              )
            else
              wrapContent,
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(BuildContext context, {required bool isWide}) {
    final wrapContent = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SpotAttributes.getKeys('features').map((key) {
                  final label = SpotAttributes.getLabel('features', key);
                  final icon = SpotAttributes.getIcon('features', key);
                  final description = SpotAttributes.getDescription('features', key);
                  final selected = selectedFeatures.contains(key);
                  return Tooltip(
                    message: description,
                    child: GestureDetector(
                      onTap: () => onToggleFeature(key, !selected),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected 
                              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected 
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon, 
                              size: 16, 
                              color: selected 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: selected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spot Features',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            if (isWide)
              Expanded(
                child: SingleChildScrollView(child: wrapContent),
              )
            else
              wrapContent,
          ],
        ),
      ),
    );
  }

  Widget _buildAccessCard(BuildContext context, {required bool isWide}) {
    final keys = SpotAttributes.getKeys('access');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spot Access',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keys.map((key) {
                final label = SpotAttributes.getLabel('access', key);
                final icon = SpotAttributes.getIcon('access', key);
                final description = SpotAttributes.getDescription('access', key);
                final selected = selectedAccess == key;
                
                // Use same colors as Spot Detail Screen
                Color backgroundColor;
                Color textColor;
                
                if (selected) {
                  switch (key) {
                    case 'public':
                      backgroundColor = Colors.green.withValues(alpha: 0.1);
                      textColor = Colors.green.shade700;
                      break;
                    case 'restricted':
                      backgroundColor = Colors.orange.withValues(alpha: 0.1);
                      textColor = Colors.orange.shade700;
                      break;
                    case 'paid':
                      backgroundColor = Colors.blue.withValues(alpha: 0.1);
                      textColor = Colors.blue.shade700;
                      break;
                    default:
                      backgroundColor = Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3);
                      textColor = Theme.of(context).colorScheme.primary;
                  }
                } else {
                  backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
                  textColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
                }
                
                return Tooltip(
                  message: description,
                  child: GestureDetector(
                    onTap: () => onAccessChanged(selected ? null : key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: textColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon, 
                            size: 16, 
                            color: textColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (selectedAccess != null) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  // Use same colors as Spot Detail Screen for description container
                  Color backgroundColor;
                  Color textColor;
                  
                  switch (selectedAccess!) {
                    case 'public':
                      backgroundColor = Colors.green.withValues(alpha: 0.1);
                      textColor = Colors.green.shade700;
                      break;
                    case 'restricted':
                      backgroundColor = Colors.orange.withValues(alpha: 0.1);
                      textColor = Colors.orange.shade700;
                      break;
                    case 'paid':
                      backgroundColor = Colors.blue.withValues(alpha: 0.1);
                      textColor = Colors.blue.shade700;
                      break;
                    default:
                      backgroundColor = Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1);
                      textColor = Theme.of(context).colorScheme.primary;
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: textColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          SpotAttributes.getIcon('access', selectedAccess!),
                          size: 16,
                          color: textColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            SpotAttributes.getDescription('access', selectedAccess!),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesCard(BuildContext context, {required bool isWide}) {
    final entries = SpotAttributes.getEntries('facilities');
    final wrapContent = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.keys.map((key) {
                  final label = SpotAttributes.getLabel('facilities', key);
                  final icon = SpotAttributes.getIcon('facilities', key);
                  final description = SpotAttributes.getDescription('facilities', key);
                  final current = selectedFacilities[key] ?? 'unknown';
                  
                  Color backgroundColor;
                  Color textColor;
                  IconData statusIcon;
                  
                  // Set colors and status icon based on status
                  if (current == 'yes') {
                    backgroundColor = Colors.green.withValues(alpha: 0.1);
                    textColor = Colors.green.shade700;
                    statusIcon = Icons.check;
                  } else if (current == 'no') {
                    backgroundColor = Colors.red.withValues(alpha: 0.1);
                    textColor = Colors.red.shade700;
                    statusIcon = Icons.close;
                  } else {
                    backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
                    textColor = Theme.of(context).colorScheme.onSurface;
                    statusIcon = Icons.help_outline;
                  }
                  
                  return Tooltip(
                    message: description,
                    child: GestureDetector(
                      onTap: () {
                        final next = current == 'yes' ? 'no' : current == 'no' ? 'unknown' : 'yes';
                        onFacilityChanged(key, next);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 16, color: textColor),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(statusIcon, size: 14, color: textColor),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spot Facilities',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            if (isWide)
              Expanded(
                child: SingleChildScrollView(child: wrapContent),
              )
            else
              wrapContent,
          ],
        ),
      ),
    );
  }
}
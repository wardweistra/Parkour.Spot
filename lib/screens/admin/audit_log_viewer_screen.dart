import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/audit_log.dart';
import '../../models/spot.dart';
import '../../models/user.dart' as app_user;
import '../../services/auth_service.dart';
import '../../services/url_service.dart';
import '../../utils/image_url_utils.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum AuditLogEntryType {
  spotCreation,
  userCreation,
  auditLogAction,
}

class AuditLogEntry {
  final AuditLogEntryType type;
  final DateTime timestamp;
  final String? id;
  final String? title;
  final String? subtitle;
  final String? details;
  final Map<String, dynamic>? metadata;

  AuditLogEntry({
    required this.type,
    required this.timestamp,
    this.id,
    this.title,
    this.subtitle,
    this.details,
    this.metadata,
  });
}

class AuditLogViewerScreen extends StatefulWidget {
  const AuditLogViewerScreen({super.key});

  @override
  State<AuditLogViewerScreen> createState() => _AuditLogViewerScreenState();
}

class _AuditLogViewerScreenState extends State<AuditLogViewerScreen> {
  List<AuditLogEntry> _entries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _pageSize = 30; // Load 30 entries per collection per page

  // Pagination cursors for each collection
  DocumentSnapshot<Map<String, dynamic>>? _lastSpotDoc;
  DocumentSnapshot<Map<String, dynamic>>? _lastUserDoc;
  DocumentSnapshot<Map<String, dynamic>>? _lastAuditLogDoc;

  // Track if there are more entries to load for each collection
  bool _hasMoreSpots = true;
  bool _hasMoreUsers = true;
  bool _hasMoreAuditLogs = true;

  @override
  void initState() {
    super.initState();
    _loadAuditLogs(reset: true);
  }

  Future<void> _loadAuditLogs({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _entries = [];
        _lastSpotDoc = null;
        _lastUserDoc = null;
        _lastAuditLogDoc = null;
        _hasMoreSpots = true;
        _hasMoreUsers = true;
        _hasMoreAuditLogs = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      List<AuditLogEntry> newEntries = [];

      // Fetch spot creations with pagination
      if (_hasMoreSpots) {
        try {
          Query<Map<String, dynamic>> spotsQuery = _firestore
              .collection('spots')
              .orderBy('createdAt', descending: true)
              .limit(_pageSize);

          if (_lastSpotDoc != null) {
            spotsQuery = spotsQuery.startAfterDocument(_lastSpotDoc!);
          }

          final spotsSnapshot = await spotsQuery.get();

          for (var doc in spotsSnapshot.docs) {
            final spot = Spot.fromFirestore(doc);
            final createdAt = spot.createdAt;
            if (createdAt != null) {
              newEntries.add(AuditLogEntry(
                type: AuditLogEntryType.spotCreation,
                timestamp: createdAt,
                id: doc.id,
                title: 'Spot Created: ${spot.name}',
                subtitle: spot.createdByName != null
                    ? 'Created by ${spot.createdByName}'
                    : spot.createdBy != null
                        ? 'Created by ${spot.createdBy}'
                        : 'Created by unknown',
                details: spot.description.isNotEmpty
                    ? spot.description
                    : '${spot.latitude.toStringAsFixed(4)}, ${spot.longitude.toStringAsFixed(4)}',
                metadata: {
                  'spotId': doc.id,
                  'spotName': spot.name,
                  'createdBy': spot.createdBy,
                  'createdByName': spot.createdByName,
                },
              ));
            }
          }

          if (spotsSnapshot.docs.isEmpty || spotsSnapshot.docs.length < _pageSize) {
            _hasMoreSpots = false;
          } else {
            _lastSpotDoc = spotsSnapshot.docs.last;
          }
        } catch (e) {
          // If orderBy fails, mark as no more spots
          _hasMoreSpots = false;
        }
      }

      // Fetch user creations with pagination
      if (_hasMoreUsers) {
        try {
          Query<Map<String, dynamic>> usersQuery = _firestore
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(_pageSize);

          if (_lastUserDoc != null) {
            usersQuery = usersQuery.startAfterDocument(_lastUserDoc!);
          }

          final usersSnapshot = await usersQuery.get();

          for (var doc in usersSnapshot.docs) {
            final createdAt = doc.data()['createdAt'] is Timestamp
                ? (doc.data()['createdAt'] as Timestamp).toDate()
                : null;
            if (createdAt != null) {
              final user = app_user.User.fromMap({
                'id': doc.id,
                ...doc.data(),
              });
              newEntries.add(AuditLogEntry(
                type: AuditLogEntryType.userCreation,
                timestamp: createdAt,
                id: doc.id,
                title: 'User Account Created',
                subtitle: user.displayName != null
                    ? '${user.displayName} (${user.email})'
                    : user.email,
                details: user.isAdmin
                    ? 'Admin account'
                    : user.isModerator
                        ? 'Moderator account'
                        : 'Regular user',
                metadata: {
                  'userId': doc.id,
                  'email': user.email,
                  'displayName': user.displayName,
                  'isAdmin': user.isAdmin,
                  'isModerator': user.isModerator,
                },
              ));
            }
          }

          if (usersSnapshot.docs.isEmpty || usersSnapshot.docs.length < _pageSize) {
            _hasMoreUsers = false;
          } else {
            _lastUserDoc = usersSnapshot.docs.last;
          }
        } catch (e) {
          // If orderBy fails, mark as no more users
          _hasMoreUsers = false;
        }
      }

      // Fetch audit log entries with pagination
      if (_hasMoreAuditLogs) {
        Query<Map<String, dynamic>> auditLogQuery = _firestore
            .collection('auditLog')
            .orderBy('timestamp', descending: true)
            .limit(_pageSize);

        if (_lastAuditLogDoc != null) {
          auditLogQuery = auditLogQuery.startAfterDocument(_lastAuditLogDoc!);
        }

        final auditLogSnapshot = await auditLogQuery.get();

        for (var doc in auditLogSnapshot.docs) {
          final auditLog = AuditLog.fromFirestore(doc);
          String title;
          String subtitle;
          String? details;

          switch (auditLog.action) {
            case AuditLogAction.spotEdit:
              title = 'Spot Edited';
              subtitle = auditLog.userName != null
                  ? 'Edited by ${auditLog.userName}'
                  : auditLog.userId != null
                      ? 'Edited by ${auditLog.userId}'
                      : 'Edited by unknown';
              // Don't set details string - we'll build a widget instead
              details = null;
              break;
            case AuditLogAction.spotMarkedAsDuplicate:
              title = 'Spot Marked as Duplicate';
              subtitle = auditLog.userName != null
                  ? 'Marked by ${auditLog.userName}'
                  : auditLog.userId != null
                      ? 'Marked by ${auditLog.userId}'
                      : 'Marked by unknown';
              if (auditLog.metadata != null &&
                  auditLog.metadata!['originalSpotId'] != null) {
                details =
                    'Original spot: ${auditLog.metadata!['originalSpotId']}';
              }
              break;
            case AuditLogAction.spotHidden:
              title = 'Spot Hidden';
              subtitle = auditLog.userName != null
                  ? 'Hidden by ${auditLog.userName}'
                  : auditLog.userId != null
                      ? 'Hidden by ${auditLog.userId}'
                      : 'Hidden by unknown';
              details = 'Spot hidden from public view';
              break;
            case AuditLogAction.spotUnhidden:
              title = 'Spot Unhidden';
              subtitle = auditLog.userName != null
                  ? 'Unhidden by ${auditLog.userName}'
                  : auditLog.userId != null
                      ? 'Unhidden by ${auditLog.userId}'
                      : 'Unhidden by unknown';
              details = 'Spot made visible to public';
              break;
            case AuditLogAction.spotReportStatusChange:
              title = 'Spot Report Status Changed';
              subtitle = auditLog.userName != null
                  ? 'Changed by ${auditLog.userName}'
                  : auditLog.userId != null
                      ? 'Changed by ${auditLog.userId}'
                      : 'Changed by unknown';
              if (auditLog.changes != null &&
                  auditLog.changes!['status'] != null) {
                final statusChange = auditLog.changes!['status'] as Map<String, dynamic>;
                final fromStatus = statusChange['from'] as String? ?? 'Unknown';
                final toStatus = statusChange['to'] as String? ?? 'Unknown';
                details = 'Status: $fromStatus → $toStatus';
                if (auditLog.reportId != null) {
                  details += '\nReport ID: ${auditLog.reportId}';
                }
              } else {
                details = 'Spot report status updated';
              }
              break;
            case AuditLogAction.spotDelete:
              title = 'Spot Deleted';
              subtitle = auditLog.userName != null
                  ? 'Deleted by ${auditLog.userName}'
                  : auditLog.userId != null
                      ? 'Deleted by ${auditLog.userId}'
                      : 'Deleted by unknown';
              if (auditLog.metadata != null) {
                final spotName = auditLog.metadata!['spotName'] as String?;
                final ratingsCount = auditLog.metadata!['ratingsCount'] as int? ?? 0;
                final spotReportsCount = auditLog.metadata!['spotReportsCount'] as int? ?? 0;
                final duplicateSpotsCount = auditLog.metadata!['duplicateSpotsCount'] as int? ?? 0;
                
                details = spotName != null ? 'Spot: $spotName' : 'Spot deleted';
                if (ratingsCount > 0 || spotReportsCount > 0 || duplicateSpotsCount > 0) {
                  details += '\nLinked data at deletion:';
                  if (ratingsCount > 0) {
                    details += '\n  • Ratings: $ratingsCount';
                  }
                  if (spotReportsCount > 0) {
                    details += '\n  • Spot Reports: $spotReportsCount';
                  }
                  if (duplicateSpotsCount > 0) {
                    details += '\n  • Duplicate Spots: $duplicateSpotsCount';
                  }
                }
              } else {
                details = 'Spot permanently deleted';
              }
              break;
          }

          newEntries.add(AuditLogEntry(
            type: AuditLogEntryType.auditLogAction,
            timestamp: auditLog.timestamp,
            id: doc.id,
            title: title,
            subtitle: subtitle,
            details: details,
            metadata: {
              'spotId': auditLog.spotId,
              if (auditLog.reportId != null) 'reportId': auditLog.reportId,
              'userId': auditLog.userId,
              'userName': auditLog.userName,
              'action': auditLog.action.toString(),
              'changes': auditLog.changes,
              'metadata': auditLog.metadata,
            },
          ));
        }

        if (auditLogSnapshot.docs.isEmpty || auditLogSnapshot.docs.length < _pageSize) {
          _hasMoreAuditLogs = false;
        } else {
          _lastAuditLogDoc = auditLogSnapshot.docs.last;
        }
      }

      // Merge with existing entries and sort by timestamp
      _entries.addAll(newEntries);
      _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load audit logs: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  bool get _hasMoreEntries => _hasMoreSpots || _hasMoreUsers || _hasMoreAuditLogs;

  /// Formats changes for display with bullet points, array diffs, and image previews
  Widget _buildChangesWidget(Map<String, dynamic> changes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: changes.entries.map((entry) {
        final fieldName = entry.key;
        final changeData = entry.value as Map<String, dynamic>;
        final fromValue = changeData['from'];
        final toValue = changeData['to'];

        // Handle array changes (like imageUrls, spotFeatures, etc.)
        if (fromValue is List || toValue is List) {
          return _buildArrayChangeItem(fieldName, fromValue, toValue);
        }

        // Handle Map changes (like spotFacilities, location, etc.)
        if (fromValue is Map || toValue is Map) {
          return _buildMapChangeItem(fieldName, fromValue, toValue);
        }

        // Handle regular field changes
        final fromFormatted = _formatValue(fromValue);
        final toFormatted = _formatValue(toValue);
        final isNullToValue = fromValue == null && toValue != null;
        final isValueToNull = fromValue != null && toValue == null;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fieldName: ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        children: [
                          TextSpan(
                            text: fromFormatted,
                            style: TextStyle(
                              color: isValueToNull ? Colors.red[700] : Colors.grey[700],
                              fontStyle: isValueToNull ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                          const TextSpan(text: ' → '),
                          TextSpan(
                            text: toFormatted,
                            style: TextStyle(
                              color: isNullToValue ? Colors.green[700] : Colors.grey[700],
                              fontStyle: isNullToValue ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Builds a widget for Map changes showing added/removed/changed keys
  Widget _buildMapChangeItem(String fieldName, dynamic fromValue, dynamic toValue) {
    // Handle null values properly - track if values were originally null
    final fromWasNull = fromValue == null;
    final toWasNull = toValue == null;
    final fromMap = fromValue is Map ? Map<String, dynamic>.from(fromValue) : (fromWasNull ? <String, dynamic>{} : null);
    final toMap = toValue is Map ? Map<String, dynamic>.from(toValue) : (toWasNull ? <String, dynamic>{} : null);

    // If either value is not a Map and not null, treat as regular change
    if (fromMap == null || toMap == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fieldName: ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatValue(fromValue)} → ${_formatValue(toValue)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Compute differences
    final allKeys = {...fromMap.keys, ...toMap.keys};
    final removed = allKeys.where((key) => fromMap.containsKey(key) && !toMap.containsKey(key)).toList();
    final added = allKeys.where((key) => !fromMap.containsKey(key) && toMap.containsKey(key)).toList();
    final changed = allKeys.where((key) => 
      fromMap.containsKey(key) && 
      toMap.containsKey(key) && 
      fromMap[key] != toMap[key]
    ).toList();
    final unchanged = allKeys.where((key) => 
      fromMap.containsKey(key) && 
      toMap.containsKey(key) && 
      fromMap[key] == toMap[key]
    ).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  '$fieldName:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (fromWasNull && toMap.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                'Added (${toMap.length} keys) - was null: ${toMap.keys.join(', ')}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                ),
              ),
            ),
          ] else if (toWasNull && fromMap.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                'Removed (${fromMap.length} keys) - now null: ${fromMap.keys.join(', ')}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[700],
                ),
              ),
            ),
          ] else ...[
            if (removed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Removed keys: ${removed.join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ],
            if (added.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Added keys: ${added.join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ],
          if (changed.isNotEmpty) ...[
            ...changed.map((key) => Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                '$key: ${_formatValue(fromMap[key])} → ${_formatValue(toMap[key])}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange[700],
                ),
              ),
            )),
          ],
          if (unchanged.isNotEmpty && removed.isEmpty && added.isEmpty && changed.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                'No changes (${unchanged.length} keys)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
          if (removed.isEmpty && added.isEmpty && changed.isEmpty && unchanged.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                fromWasNull && toWasNull
                    ? 'Was null, now null'
                    : 'No items (was empty, now empty)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a widget for array changes showing added/removed items
  Widget _buildArrayChangeItem(String fieldName, dynamic fromValue, dynamic toValue) {
    // Handle null values properly - track if values were originally null
    final fromWasNull = fromValue == null;
    final toWasNull = toValue == null;
    final fromList = fromValue is List ? fromValue : (fromWasNull ? <dynamic>[] : null);
    final toList = toValue is List ? toValue : (toWasNull ? <dynamic>[] : null);

    // If either value is not a list and not null, treat as regular change
    if (fromList == null || toList == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fieldName: ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatValue(fromValue)} → ${_formatValue(toValue)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Compute differences
    final removed = fromList.where((item) => !toList.contains(item)).toList();
    final added = toList.where((item) => !fromList.contains(item)).toList();
    final unchanged = fromList.where((item) => toList.contains(item)).toList();

    // Special handling for images
    if (fieldName == 'imageUrls') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    '$fieldName:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (fromWasNull && toList.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Added (${toList.length}) - was null:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: toList.map((url) => _buildImagePreview(url.toString(), isRemoved: false)).toList(),
                ),
              ),
            ] else if (removed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Removed (${removed.length}):',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: removed.map((url) => _buildImagePreview(url.toString(), isRemoved: true)).toList(),
                ),
              ),
            ],
            if (toWasNull && fromList.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Removed (${fromList.length}) - now null:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: fromList.map((url) => _buildImagePreview(url.toString(), isRemoved: true)).toList(),
                ),
              ),
            ] else if (added.isNotEmpty && !fromWasNull) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Added (${added.length}):',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: added.map((url) => _buildImagePreview(url.toString(), isRemoved: false)).toList(),
                ),
              ),
            ],
            if (unchanged.isNotEmpty && (removed.isNotEmpty || added.isNotEmpty)) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Unchanged (${unchanged.length}):',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: unchanged.map((url) => _buildImagePreview(url.toString(), isRemoved: false)).toList(),
                ),
              ),
            ],
            // Show message if both lists are empty
            if (removed.isEmpty && added.isEmpty && unchanged.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  fromWasNull && toWasNull
                      ? 'Was null, now null'
                      : 'No items (was empty, now empty)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Regular array handling (non-image arrays)
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  '$fieldName:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (fromWasNull && toList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                'Added (${toList.length}) - was null: ${toList.map((e) => _formatValue(e)).join(', ')}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                ),
              ),
            ),
          ] else if (toWasNull && fromList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                'Removed (${fromList.length}) - now null: ${fromList.map((e) => _formatValue(e)).join(', ')}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[700],
                ),
              ),
            ),
          ] else ...[
            if (removed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Removed: ${removed.map((e) => _formatValue(e)).join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ],
            if (added.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Added: ${added.map((e) => _formatValue(e)).join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ],
          if (unchanged.isNotEmpty && removed.isEmpty && added.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                'No changes (${unchanged.length} items)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
          // Show message if both lists are empty
          if (removed.isEmpty && added.isEmpty && unchanged.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                fromWasNull && toWasNull
                    ? 'Was null, now null'
                    : 'No items (was empty, now empty)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a small image preview widget
  Widget _buildImagePreview(String imageUrl, {required bool isRemoved}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isRemoved ? Colors.red : Colors.green,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: CachedNetworkImage(
              imageUrl: getResizedImageUrl(imageUrl),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: Icon(
                  Icons.image_not_supported,
                  size: 24,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
        if (isRemoved)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(
                  Icons.remove_circle,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Formats a value for display
  String _formatValue(dynamic value) {
    if (value == null) return '(null)';
    if (value is String) {
      if (value.isEmpty) return '(empty string)';
      return value;
    }
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    if (value is DateTime) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
    }
    if (value is Map) {
      if (value.isEmpty) return '(empty map)';
      return '{${value.length} keys}';
    }
    if (value is List) {
      if (value.isEmpty) return '(empty list)';
      return '[${value.length} items]';
    }
    return value.toString();
  }

  IconData _getIconForType(AuditLogEntryType type) {
    switch (type) {
      case AuditLogEntryType.spotCreation:
        return Icons.add_location;
      case AuditLogEntryType.userCreation:
        return Icons.person_add;
      case AuditLogEntryType.auditLogAction:
        return Icons.edit;
    }
  }

  Color _getColorForType(AuditLogEntryType type) {
    switch (type) {
      case AuditLogEntryType.spotCreation:
        return Colors.green;
      case AuditLogEntryType.userCreation:
        return Colors.blue;
      case AuditLogEntryType.auditLogAction:
        return Colors.orange;
    }
  }

  /// Check if an entry is a spot report status change
  bool _isSpotReportStatusChange(AuditLogEntry entry) {
    if (entry.type == AuditLogEntryType.auditLogAction) {
      final action = entry.metadata?['action'] as String?;
      if (action != null) {
        // Action is stored as enum.toString(), e.g., "AuditLogAction.spotReportStatusChange"
        // or just "spotReportStatusChange" depending on how it's stored
        return action.contains('spotReportStatusChange');
      }
    }
    return false;
  }

  /// Check if an entry is a user account creation
  bool _isUserCreation(AuditLogEntry entry) {
    return entry.type == AuditLogEntryType.userCreation;
  }

  /// Get list of spot IDs from an audit log entry
  /// Returns original spot first (if applicable), then the main spot
  List<String> _getSpotIdsFromEntry(AuditLogEntry entry) {
    final spotIds = <String>[];
    
    if (entry.type == AuditLogEntryType.spotCreation) {
      // For spot creation, the id is the spot ID
      if (entry.id != null) {
        spotIds.add(entry.id!);
      } else if (entry.metadata?['spotId'] != null) {
        spotIds.add(entry.metadata!['spotId'] as String);
      }
    } else if (entry.type == AuditLogEntryType.auditLogAction) {
      // For duplicate actions, add original spot first, then the duplicate
      if (entry.metadata?['metadata'] != null) {
        final nestedMetadata = entry.metadata!['metadata'] as Map<String, dynamic>?;
        if (nestedMetadata?['originalSpotId'] != null) {
          final originalSpotId = nestedMetadata!['originalSpotId'] as String;
          spotIds.add(originalSpotId);
        }
      }
      
      // Then add the main spot (duplicate spot for duplicate actions)
      if (entry.metadata?['spotId'] != null) {
        final spotId = entry.metadata!['spotId'] as String;
        if (!spotIds.contains(spotId)) {
          spotIds.add(spotId);
        }
      }
    }
    
    return spotIds;
  }

  /// Navigate to a spot by fetching it first to get location info
  Future<void> _navigateToSpot(String spotId) async {
    try {
      final spotDoc = await _firestore.collection('spots').doc(spotId).get();
      if (spotDoc.exists) {
        final spot = Spot.fromFirestore(spotDoc);
        final navigationUrl = UrlService.generateNavigationUrl(
          spotId,
          countryCode: spot.countryCode,
          city: spot.city,
        );
        if (mounted) {
          context.go(navigationUrl);
        }
      } else {
        // Fallback to simple route if spot doesn't exist
        if (mounted) {
          context.go('/spot/$spotId');
        }
      }
    } catch (e) {
      // Fallback to simple route on error
      if (mounted) {
        context.go('/spot/$spotId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit Log')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 12),
                const Text('Administrator access required'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/explore?tab=profile'),
                  child: const Text('Back to Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log Viewer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAuditLogs(reset: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAuditLogs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _entries.isEmpty
                  ? const Center(
                      child: Text('No audit log entries found'),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadAuditLogs(reset: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _entries.length + (_hasMoreEntries ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show "Load More" button at the end
                          if (index == _entries.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: _isLoadingMore
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton.icon(
                                        onPressed: _hasMoreEntries
                                            ? () => _loadAuditLogs()
                                            : null,
                                        icon: const Icon(Icons.expand_more),
                                        label: const Text('Load More'),
                                      ),
                              ),
                            );
                          }

                          final entry = _entries[index];
                          final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
                          final formattedDate =
                              dateFormat.format(entry.timestamp);

                          final spotIds = _getSpotIdsFromEntry(entry);
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _getColorForType(entry.type).withOpacity(0.2),
                                child: Icon(
                                  _getIconForType(entry.type),
                                  color: _getColorForType(entry.type),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                entry.title ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.subtitle ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  // Show changes widget for Spot Edited entries
                                  if (entry.type == AuditLogEntryType.auditLogAction &&
                                      entry.metadata?['action'] != null &&
                                      entry.metadata!['action'].toString().contains('spotEdit') &&
                                      entry.metadata?['changes'] != null &&
                                      (entry.metadata!['changes'] as Map<String, dynamic>).isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildChangesWidget(
                                      entry.metadata!['changes'] as Map<String, dynamic>,
                                    ),
                                  ] else if (entry.details != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.details!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: (spotIds.isNotEmpty || _isSpotReportStatusChange(entry) || _isUserCreation(entry))
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Spot buttons
                                        ...spotIds.asMap().entries.map((spotEntry) {
                                          final isLast = spotEntry.key == spotIds.length - 1;
                                          final hasOtherButtons = _isSpotReportStatusChange(entry) || _isUserCreation(entry);
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              right: isLast && !hasOtherButtons ? 0 : 4,
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                spotIds.length > 1 && spotEntry.key == 0
                                                    ? Icons.location_on
                                                    : Icons.open_in_new,
                                                size: 20,
                                              ),
                                              tooltip: spotIds.length > 1 && spotEntry.key == 0
                                                  ? 'Open original spot'
                                                  : spotIds.length > 1
                                                      ? 'Open duplicate spot'
                                                      : 'Open spot',
                                              onPressed: () => _navigateToSpot(spotEntry.value),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          );
                                        }),
                                        // Spot Report Queue button
                                        if (_isSpotReportStatusChange(entry))
                                          IconButton(
                                            icon: const Icon(
                                              Icons.report_problem,
                                              size: 20,
                                            ),
                                            tooltip: 'Open Spot Report Queue',
                                            onPressed: () => context.go('/moderator/reports'),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        // User Management button
                                        if (_isUserCreation(entry))
                                          IconButton(
                                            icon: const Icon(
                                              Icons.people_outline,
                                              size: 20,
                                            ),
                                            tooltip: 'Open User Management',
                                            onPressed: () => context.go('/admin/users'),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                      ],
                                    )
                                  : null,
                              isThreeLine: true,
                              onTap: () {
                                // Show details dialog
                                final dialogSpotIds = _getSpotIdsFromEntry(entry);
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(entry.title ?? 'Details'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Type: ${entry.type.name}'),
                                          const SizedBox(height: 8),
                                          Text('Timestamp: $formattedDate'),
                                          if (entry.id != null) ...[
                                            const SizedBox(height: 8),
                                            Text('ID: ${entry.id}'),
                                          ],
                                          // Show changes widget for Spot Edited entries
                                          if (entry.type == AuditLogEntryType.auditLogAction &&
                                              entry.metadata?['action'] != null &&
                                              entry.metadata!['action'].toString().contains('spotEdit') &&
                                              entry.metadata?['changes'] != null &&
                                              (entry.metadata!['changes'] as Map<String, dynamic>).isNotEmpty) ...[
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Changes:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildChangesWidget(
                                              entry.metadata!['changes'] as Map<String, dynamic>,
                                            ),
                                          ],
                                          if (dialogSpotIds.isNotEmpty) ...[
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Related Spots:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            ...dialogSpotIds.asMap().entries.map(
                                              (spotEntry) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        dialogSpotIds.length > 1 && spotEntry.key == 0
                                                            ? 'Original: ${spotEntry.value}'
                                                            : dialogSpotIds.length > 1
                                                                ? 'Duplicate: ${spotEntry.value}'
                                                                : 'Spot: ${spotEntry.value}',
                                                        style: const TextStyle(
                                                            fontSize: 12),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.open_in_new,
                                                        size: 20,
                                                      ),
                                                      tooltip: 'Open spot',
                                                      onPressed: () {
                                                        Navigator.of(context).pop();
                                                        _navigateToSpot(spotEntry.value);
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (entry.metadata != null &&
                                              entry.metadata!.isNotEmpty &&
                                              !(entry.type == AuditLogEntryType.auditLogAction &&
                                                entry.metadata?['action'] != null &&
                                                entry.metadata!['action'].toString().contains('spotEdit'))) ...[
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Metadata:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            ...entry.metadata!.entries
                                                .where((e) => e.key != 'changes') // Exclude changes as it's shown separately
                                                .map(
                                              (e) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4),
                                                child: Text(
                                                  '${e.key}: ${e.value}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      if (dialogSpotIds.isNotEmpty) ...[
                                        ...dialogSpotIds.asMap().entries.map(
                                          (spotEntry) => TextButton.icon(
                                            icon: Icon(
                                              dialogSpotIds.length > 1 && spotEntry.key == 0
                                                  ? Icons.location_on
                                                  : Icons.open_in_new,
                                              size: 18,
                                            ),
                                            label: Text(
                                              dialogSpotIds.length > 1 && spotEntry.key == 0
                                                  ? 'Open Original'
                                                  : dialogSpotIds.length > 1
                                                      ? 'Open Duplicate'
                                                      : 'Open Spot',
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _navigateToSpot(spotEntry.value);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (_isSpotReportStatusChange(entry))
                                        TextButton.icon(
                                          icon: const Icon(
                                            Icons.report_problem,
                                            size: 18,
                                          ),
                                          label: const Text('Open Report Queue'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            context.go('/moderator/reports');
                                          },
                                        ),
                                      if (_isUserCreation(entry))
                                        TextButton.icon(
                                          icon: const Icon(
                                            Icons.people_outline,
                                            size: 18,
                                          ),
                                          label: const Text('Open User Management'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            context.go('/admin/users');
                                          },
                                        ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}


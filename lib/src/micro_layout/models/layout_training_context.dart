import 'dart:ui';

class ConnectionSideProfile {
  final int top;
  final int right;
  final int bottom;
  final int left;

  const ConnectionSideProfile({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  int get total => top + right + bottom + left;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'top': top,
      'right': right,
      'bottom': bottom,
      'left': left,
    };
  }

  factory ConnectionSideProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionSideProfile(
      top: (json['top'] as num?)?.toInt() ?? 0,
      right: (json['right'] as num?)?.toInt() ?? 0,
      bottom: (json['bottom'] as num?)?.toInt() ?? 0,
      left: (json['left'] as num?)?.toInt() ?? 0,
    );
  }
}

class LayoutTrainingContext {
  final int schemaVersion;
  final String datasetSchemaTag;
  final String datasetKind;
  final String outcomeKind;
  final String sampleSource;
  final String qType;
  final bool isManualSample;
  final bool isConflictNode;
  final int totalConnectionCount;
  final int incidentArrowCount;
  final ConnectionSideProfile nodeConnectionsBefore;
  final ConnectionSideProfile attributeConnectionsBefore;
  final ConnectionSideProfile nodeConnectionsAfter;
  final ConnectionSideProfile attributeConnectionsAfter;
  final double sourceNodeOverlapCount;
  final double sourceEdgeIntersectionCount;
  final double sourceEdgeCrossings;
  final double sourceIncidentArrowLength;
  final double resultNodeOverlapCount;
  final double resultEdgeIntersectionCount;
  final double resultEdgeCrossings;
  final double resultIncidentArrowLength;
  final double movementDistance;
  final bool hasDeferredOutcome;
  final int deferredStepsObserved;
  final int deferredStepsToResolution;
  final double? deferredScore;
  final bool? deferredAccepted;
  final Rect? freeSpaceBounds;
  final String? sessionId;
  final int sequenceIndex;
  final int graphNodeCount;
  final int graphEdgeCount;
  final double graphConflictRatio;

  const LayoutTrainingContext({
    this.schemaVersion = 5,
    this.datasetSchemaTag = 'neural_polish_v5',
    this.datasetKind = 'auto_immediate',
    this.outcomeKind = 'immediate',
    required this.sampleSource,
    required this.qType,
    required this.isManualSample,
    required this.isConflictNode,
    required this.totalConnectionCount,
    required this.incidentArrowCount,
    required this.nodeConnectionsBefore,
    required this.attributeConnectionsBefore,
    required this.nodeConnectionsAfter,
    required this.attributeConnectionsAfter,
    required this.sourceNodeOverlapCount,
    required this.sourceEdgeIntersectionCount,
    required this.sourceEdgeCrossings,
    required this.sourceIncidentArrowLength,
    required this.resultNodeOverlapCount,
    required this.resultEdgeIntersectionCount,
    required this.resultEdgeCrossings,
    required this.resultIncidentArrowLength,
    required this.movementDistance,
    this.hasDeferredOutcome = false,
    this.deferredStepsObserved = 0,
    this.deferredStepsToResolution = 0,
    this.deferredScore,
    this.deferredAccepted,
    this.freeSpaceBounds,
    this.sessionId,
    this.sequenceIndex = 0,
    this.graphNodeCount = 0,
    this.graphEdgeCount = 0,
    this.graphConflictRatio = 0,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'datasetSchemaTag': datasetSchemaTag,
      'datasetKind': datasetKind,
      'outcomeKind': outcomeKind,
      'sampleSource': sampleSource,
      'qType': qType,
      'isManualSample': isManualSample,
      'isConflictNode': isConflictNode,
      'totalConnectionCount': totalConnectionCount,
      'incidentArrowCount': incidentArrowCount,
      'nodeConnectionsBefore': nodeConnectionsBefore.toJson(),
      'attributeConnectionsBefore': attributeConnectionsBefore.toJson(),
      'nodeConnectionsAfter': nodeConnectionsAfter.toJson(),
      'attributeConnectionsAfter': attributeConnectionsAfter.toJson(),
      'sourceNodeOverlapCount': sourceNodeOverlapCount,
      'sourceEdgeIntersectionCount': sourceEdgeIntersectionCount,
      'sourceEdgeCrossings': sourceEdgeCrossings,
      'sourceIncidentArrowLength': sourceIncidentArrowLength,
      'resultNodeOverlapCount': resultNodeOverlapCount,
      'resultEdgeIntersectionCount': resultEdgeIntersectionCount,
      'resultEdgeCrossings': resultEdgeCrossings,
      'resultIncidentArrowLength': resultIncidentArrowLength,
      'movementDistance': movementDistance,
      'hasDeferredOutcome': hasDeferredOutcome,
      'deferredStepsObserved': deferredStepsObserved,
      'deferredStepsToResolution': deferredStepsToResolution,
      'deferredScore': deferredScore,
      'deferredAccepted': deferredAccepted,
      'freeSpaceBounds': freeSpaceBounds == null
          ? null
          : <String, dynamic>{
              'left': freeSpaceBounds!.left,
              'top': freeSpaceBounds!.top,
              'right': freeSpaceBounds!.right,
              'bottom': freeSpaceBounds!.bottom,
            },
      'sessionId': sessionId,
      'sequenceIndex': sequenceIndex,
      'graphNodeCount': graphNodeCount,
      'graphEdgeCount': graphEdgeCount,
      'graphConflictRatio': graphConflictRatio,
    };
  }

  factory LayoutTrainingContext.fromJson(Map<String, dynamic> json) {
    final freeSpaceJson = json['freeSpaceBounds'] as Map<String, dynamic>?;
    return LayoutTrainingContext(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 5,
      datasetSchemaTag: json['datasetSchemaTag'] as String? ?? 'neural_polish_v5',
      datasetKind: json['datasetKind'] as String? ?? 'auto_immediate',
      outcomeKind: json['outcomeKind'] as String? ?? 'immediate',
      sampleSource: json['sampleSource'] as String? ?? 'auto',
      qType: json['qType'] as String? ?? 'None',
      isManualSample: json['isManualSample'] as bool? ?? false,
      isConflictNode: json['isConflictNode'] as bool? ?? false,
      totalConnectionCount: (json['totalConnectionCount'] as num?)?.toInt() ?? 0,
      incidentArrowCount: (json['incidentArrowCount'] as num?)?.toInt() ?? 0,
      nodeConnectionsBefore: ConnectionSideProfile.fromJson(
        json['nodeConnectionsBefore'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      attributeConnectionsBefore: ConnectionSideProfile.fromJson(
        json['attributeConnectionsBefore'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      nodeConnectionsAfter: ConnectionSideProfile.fromJson(
        json['nodeConnectionsAfter'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      attributeConnectionsAfter: ConnectionSideProfile.fromJson(
        json['attributeConnectionsAfter'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      sourceNodeOverlapCount: (json['sourceNodeOverlapCount'] as num?)?.toDouble() ?? 0,
      sourceEdgeIntersectionCount: (json['sourceEdgeIntersectionCount'] as num?)?.toDouble() ?? 0,
      sourceEdgeCrossings: (json['sourceEdgeCrossings'] as num?)?.toDouble() ?? 0,
      sourceIncidentArrowLength: (json['sourceIncidentArrowLength'] as num?)?.toDouble() ?? 0,
      resultNodeOverlapCount: (json['resultNodeOverlapCount'] as num?)?.toDouble() ?? 0,
      resultEdgeIntersectionCount: (json['resultEdgeIntersectionCount'] as num?)?.toDouble() ?? 0,
      resultEdgeCrossings: (json['resultEdgeCrossings'] as num?)?.toDouble() ?? 0,
      resultIncidentArrowLength: (json['resultIncidentArrowLength'] as num?)?.toDouble() ?? 0,
      movementDistance: (json['movementDistance'] as num?)?.toDouble() ?? 0,
      hasDeferredOutcome: json['hasDeferredOutcome'] as bool? ?? false,
      deferredStepsObserved: (json['deferredStepsObserved'] as num?)?.toInt() ?? 0,
      deferredStepsToResolution: (json['deferredStepsToResolution'] as num?)?.toInt() ?? 0,
      deferredScore: (json['deferredScore'] as num?)?.toDouble(),
      deferredAccepted: json['deferredAccepted'] as bool?,
      freeSpaceBounds: freeSpaceJson == null
          ? null
          : Rect.fromLTRB(
              (freeSpaceJson['left'] as num?)?.toDouble() ?? 0,
              (freeSpaceJson['top'] as num?)?.toDouble() ?? 0,
              (freeSpaceJson['right'] as num?)?.toDouble() ?? 0,
              (freeSpaceJson['bottom'] as num?)?.toDouble() ?? 0,
            ),
      sessionId: json['sessionId'] as String?,
      sequenceIndex: (json['sequenceIndex'] as num?)?.toInt() ?? 0,
      graphNodeCount: (json['graphNodeCount'] as num?)?.toInt() ?? 0,
      graphEdgeCount: (json['graphEdgeCount'] as num?)?.toInt() ?? 0,
      graphConflictRatio: (json['graphConflictRatio'] as num?)?.toDouble() ?? 0,
    );
  }
}

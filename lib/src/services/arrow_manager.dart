import 'dart:ui';

import '../models/table.node.dart';
import '../models/arrow.dart';

/// Service for managing and calculating arrow connections
class ArrowManager {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;

  ArrowManager({
    required this.arrows,
    required this.nodes,
    required this.nodeBoundsCache,
  });

  /// Get all arrows connected to a specific node on a specific side
  List<Arrow> getArrowsOnSide(String nodeId, String side) {
    final result = <Arrow>[];
    
    for (final arrow in arrows) {
      // Check if the arrow connects to this node as source or target
      if (arrow.source == nodeId) {
        // Check which side is used for the source
        if (getSideForConnection(arrow, true) == side) {
          result.add(arrow);
        }
      } else if (arrow.target == nodeId) {
        // Check which side is used for the target
        if (getSideForConnection(arrow, false) == side) {
          result.add(arrow);
        }
      }
    }
    
    return result;
  }

  /// Get the index of a specific arrow among all arrows connected to a node side
  int getConnectionIndex(Arrow targetArrow, String nodeId, String side) {
    int index = 0;
    
    for (int i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      
      // Skip if this is the target arrow itself
      if (arrow.id == targetArrow.id) {
        break;
      }
      
      // Check if this arrow connects to the node as source or target
      if (arrow.source == nodeId) {
        // Check which side is used for the source
        if (getSideForConnection(arrow, true) == side) {
          index++;
        }
      } else if (arrow.target == nodeId) {
        // Check which side is used for the target
        if (getSideForConnection(arrow, false) == side) {
          index++;
        }
      }
    }
    
    return index;
  }

  /// Get the count of arrows connected to a specific node on a specific side
  int getConnectionsCountOnSide(String nodeId, String side) {
    return getArrowsOnSide(nodeId, side).length;
  }

  /// Determine the side where an arrow connects to a node (for source or target)
  String getSideForConnection(Arrow arrow, bool isSource) {
    // Find source and target nodes
    final sourceNode = _findNodeById(arrow.source);
    final targetNode = _findNodeById(arrow.target);
    
    if (sourceNode == null || targetNode == null) {
      return 'top'; // fallback
    }
    
    // Get absolute positions of nodes
    final sourceAbsolutePos = sourceNode.aPosition ?? sourceNode.position;
    final targetAbsolutePos = targetNode.aPosition ?? targetNode.position;
    
    // Create Rects for nodes
    final sourceRect = Rect.fromPoints(
      sourceAbsolutePos,
      Offset(
        sourceAbsolutePos.dx + sourceNode.size.width,
        sourceAbsolutePos.dy + sourceNode.size.height,
      ),
    );
    
    final targetRect = Rect.fromPoints(
      targetAbsolutePos,
      Offset(
        targetAbsolutePos.dx + targetNode.size.width,
        targetAbsolutePos.dy + targetNode.size.height,
      ),
    );
    
    // Calculate connection points
    final connectionPoints = _calculateConnectionPoints(sourceRect, targetRect, sourceNode, targetNode);
    
    if (isSource) {
      return _getSideFromPoint(connectionPoints.start!, sourceRect);
    } else {
      return _getSideFromPoint(connectionPoints.end!, targetRect);
    }
  }

  /// Find a node by ID
  TableNode? _findNodeById(String id) {
    return nodes.firstWhereOrNull((node) => node.id == id);
  }

  /// Calculate connection points between two nodes
  ({Offset? end, Offset? start}) _calculateConnectionPoints(Rect sourceRect, Rect targetRect, TableNode sourceNode, TableNode targetNode) {
    // Determine center points of nodes
    final sourceCenter = sourceRect.center;
    final targetCenter = targetRect.center;

    // Determine node sides
    final sourceTop = sourceRect.top;
    final sourceBottom = sourceRect.bottom;
    final sourceLeft = sourceRect.left;
    final sourceRight = sourceRect.right;
    
    final targetTop = targetRect.top;
    final targetBottom = targetRect.bottom;
    final targetLeft = targetRect.left;
    final targetRight = targetRect.right;

    Offset? startConnectionPoint;
    Offset? endConnectionPoint;

    // Calculate distances between centers
    final dx = targetCenter.dx - sourceCenter.dx;
    final dy = targetCenter.dy - sourceCenter.dy;

    // Determine source side (where connection starts)
    if (dx < 0 && dy < 0 && dx.abs() > 20 && sourceCenter.dy < targetTop - 20) {
      // Center of source node is to the left and above the top of the target node by >20
      startConnectionPoint = Offset(sourceRight - 6, sourceCenter.dy);
      endConnectionPoint = Offset(targetCenter.dx, targetTop + 6);
    } else if (dx < 0 && dy > 0 && dx.abs() > 40 && sourceCenter.dy > targetTop + 20) {
      // Center of source node is to the left (>40 distance) and below top+20 of target node
      startConnectionPoint = Offset(sourceRight - 6, sourceCenter.dy);
      endConnectionPoint = Offset(targetLeft + 6, targetCenter.dy);
    } else if (dx < 0 && dy > 0 && dx.abs() <= 40 && sourceCenter.dy > targetTop + 20) {
      // Center of source node is to the left (<=40 distance) and below top+20 of target node
      startConnectionPoint = Offset(sourceCenter.dx, sourceTop + 6);
      endConnectionPoint = Offset(targetCenter.dx, targetTop + 6);
    } else if (dx < 0 && dy > 0 && sourceCenter.dy > targetBottom + 20) {
      // Center of source node is to the left and below the bottom of target node by >20
      startConnectionPoint = Offset(sourceRight - 6, sourceCenter.dy);
      endConnectionPoint = Offset(targetCenter.dx, targetBottom - 6);
    } else if (dx < 0 && dy > 0 && dx.abs() > 40 && sourceCenter.dy > targetBottom - 20) {
      // Center of source node is to the left (>40 distance) and below <20 of bottom of target node
      startConnectionPoint = Offset(sourceRight - 6, sourceCenter.dy);
      endConnectionPoint = Offset(targetLeft + 6, targetCenter.dy);
    } else if (dx < 0 && dy > 0 && dx.abs() <= 40 && sourceCenter.dy > targetBottom - 20) {
      // Center of source node is to the left (<=40 distance) and below <20 of bottom of target node
      startConnectionPoint = Offset(sourceCenter.dx, sourceBottom - 6);
      endConnectionPoint = Offset(targetCenter.dx, targetBottom - 6);
    } else {
      // For other cases, use algorithm similar to the original
      // Determine main direction of connection
      if (dx.abs() >= dy.abs()) {
        // Horizontal direction prevails
        if (dx > 0) {
          // To the right
          startConnectionPoint = Offset(sourceRight - 6, sourceCenter.dy);
          endConnectionPoint = Offset(targetLeft + 6, targetCenter.dy);
        } else {
          // To the left
          startConnectionPoint = Offset(sourceLeft + 6, sourceCenter.dy);
          endConnectionPoint = Offset(targetRight - 6, targetCenter.dy);
        }
      } else {
        // Vertical direction prevails
        if (dy > 0) {
          // Downward
          startConnectionPoint = Offset(sourceCenter.dx, sourceBottom - 6);
          endConnectionPoint = Offset(targetCenter.dx, targetTop + 6);
        } else {
          // Upward
          startConnectionPoint = Offset(sourceCenter.dx, sourceTop + 6);
          endConnectionPoint = Offset(targetCenter.dx, targetBottom - 6);
        }
      }
    }

    return (start: startConnectionPoint, end: endConnectionPoint);
  }

  /// Determine which side of a node a point belongs to
  String _getSideFromPoint(Offset point, Rect rect) {
    if ((point.dx - rect.left).abs() < 1) {
      return 'left';
    } else if ((point.dx - rect.right).abs() < 1) {
      return 'right';
    } else if ((point.dy - rect.top).abs() < 1) {
      return 'top';
    } else {
      return 'bottom';
    }
  }

  /// Distribute connection points along a side with step 10
  Offset distributeConnectionPoint(Offset originalPoint, Rect rect, String side, String nodeId, Arrow arrow) {
    // Count the number of connections attached to this side of the node
    int connectionsCount = getConnectionsCountOnSide(nodeId, side);
    
    // If only one connection on this side, use the central point
    if (connectionsCount <= 1) {
      return originalPoint;
    }
    
    // Find the index of the current connection among all connections attached to this side
    int index = getConnectionIndex(arrow, nodeId, side);
    
    // Calculate offset for even distribution
    double offset = 0.0;
    switch (side) {
      case 'top':
      case 'bottom':
        // For horizontal sides (top/bottom) offset along X-axis
        double sideLength = rect.width;
        // Center point of the side
        double centerPoint = rect.center.dx;
        
        // If odd number of connections, the center stays in the middle, others are distributed on sides
        if (connectionsCount % 2 == 1) {
          // Odd number of connections
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Left points
            offset = -(halfCount - index) * 10.0;
          } else if (index == halfCount) {
            // Central point
            offset = 0.0;
          } else {
            // Right points
            offset = (index - halfCount) * 10.0;
          }
        } else {
          // Even number of connections
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Left points
            offset = -(halfCount - index - 0.5) * 10.0;
          } else {
            // Right points
            offset = (index - halfCount + 0.5) * 10.0;
          }
        }
        
        // Make sure the point does not go beyond the side limits
        double clampedOffset = offset.clamp(
          -sideLength / 2 + 6, // Minimum offset from edge (considering 6 offset)
          sideLength / 2 - 6   // Maximum offset from edge (considering 6 offset)
        );
        
        return Offset(centerPoint + clampedOffset, originalPoint.dy);
        
      case 'left':
      case 'right':
        // For vertical sides (left/right) offset along Y-axis
        double sideLength = rect.height;
        // Center point of the side
        double centerPoint = rect.center.dy;
        
        // If odd number of connections, the center stays in the middle, others are distributed on sides
        if (connectionsCount % 2 == 1) {
          // Odd number of connections
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Top points
            offset = -(halfCount - index) * 10.0;
          } else if (index == halfCount) {
            // Central point
            offset = 0.0;
          } else {
            // Bottom points
            offset = (index - halfCount) * 10.0;
          }
        } else {
          // Even number of connections
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Top points
            offset = -(halfCount - index - 0.5) * 10.0;
          } else {
            // Bottom points
            offset = (index - halfCount + 0.5) * 10.0;
          }
        }
        
        // Make sure the point does not go beyond the side limits
        double clampedOffset = offset.clamp(
          -sideLength / 2 + 6, // Minimum offset from edge (considering 6 offset)
          sideLength / 2 - 6   // Maximum offset from edge (considering 6 offset)
        );
        
        return Offset(originalPoint.dx, centerPoint + clampedOffset);
        
      default:
        return originalPoint;
    }
  }
}
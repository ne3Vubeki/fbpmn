/**
 * JavaScript wrapper for Cola WASM module
 * Provides a convenient API for use from Dart via js_interop
 */

let colaModule = null;
let colaReady = false;

// Helper functions for memory access (polyfills for setValue/getValue)
function _setValue(ptr, value, type) {
    switch (type) {
        case 'i8':
            colaModule.HEAP8[ptr] = value;
            break;
        case 'i16':
            colaModule.HEAP16[ptr >> 1] = value;
            break;
        case 'i32':
            colaModule.HEAP32[ptr >> 2] = value;
            break;
        case 'float':
            colaModule.HEAPF32[ptr >> 2] = value;
            break;
        case 'double':
            colaModule.HEAPF64[ptr >> 3] = value;
            break;
        default:
            colaModule.HEAP32[ptr >> 2] = value;
    }
}

function _getValue(ptr, type) {
    switch (type) {
        case 'i8':
            return colaModule.HEAP8[ptr];
        case 'i16':
            return colaModule.HEAP16[ptr >> 1];
        case 'i32':
            return colaModule.HEAP32[ptr >> 2];
        case 'float':
            return colaModule.HEAPF32[ptr >> 2];
        case 'double':
            return colaModule.HEAPF64[ptr >> 3];
        default:
            return colaModule.HEAP32[ptr >> 2];
    }
}

// Get the appropriate setValue/getValue function
function getSetValue() {
    if (colaModule.setValue) return colaModule.setValue;
    if (colaModule.HEAP32) return _setValue;
    throw new Error('No memory access method available');
}

function getGetValue() {
    if (colaModule.getValue) return colaModule.getValue;
    if (colaModule.HEAP32) return _getValue;
    throw new Error('No memory access method available');
}

/**
 * Initialize the Cola WASM module
 * Must be called before using any other functions
 * @returns {Promise<void>}
 */
async function initCola() {
    if (colaReady) return;
    
    colaModule = await ColaModule();
    colaReady = true;
    
    // Debug: check available memory access methods
    console.log('Cola WASM module initialized');
    console.log('  setValue available:', typeof colaModule.setValue === 'function');
    console.log('  getValue available:', typeof colaModule.getValue === 'function');
    console.log('  HEAP32 available:', !!colaModule.HEAP32);
    console.log('  HEAPF64 available:', !!colaModule.HEAPF64);
}

/**
 * Check if Cola is ready
 * @returns {boolean}
 */
function isColaReady() {
    return colaReady;
}

/**
 * Layout class - wraps the C API in a convenient object
 */
class ColaLayout {
    /**
     * Create a new layout
     * @param {number} nodeCount - Number of nodes
     * @param {number} idealEdgeLength - Default ideal edge length (default: 100)
     */
    constructor(nodeCount, idealEdgeLength = 100) {
        if (!colaReady) {
            throw new Error('Cola not initialized. Call initCola() first.');
        }
        
        this._nodeCount = nodeCount;
        this._ptr = colaModule._cola_create_layout(nodeCount, idealEdgeLength);
        this._positionsBuffer = null;
        this._destroyed = false;
    }
    
    /**
     * Set node position and size
     * @param {number} nodeId - Node index (0-based)
     * @param {number} x - Center X position
     * @param {number} y - Center Y position
     * @param {number} width - Node width
     * @param {number} height - Node height
     */
    setNode(nodeId, x, y, width, height) {
        this._checkDestroyed();
        colaModule._cola_set_node(this._ptr, nodeId, x, y, width, height);
    }
    
    /**
     * Set multiple nodes at once
     * @param {Array<{x: number, y: number, width: number, height: number}>} nodes
     */
    setNodes(nodes) {
        this._checkDestroyed();
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            colaModule._cola_set_node(this._ptr, i, n.x, n.y, n.width, n.height);
        }
    }
    
    /**
     * Add an edge between two nodes
     * @param {number} source - Source node index
     * @param {number} target - Target node index
     */
    addEdge(source, target) {
        this._checkDestroyed();
        colaModule._cola_add_edge(this._ptr, source, target);
    }
    
    /**
     * Add multiple edges at once
     * @param {Array<{source: number, target: number}>} edges
     */
    addEdges(edges) {
        this._checkDestroyed();
        for (const e of edges) {
            colaModule._cola_add_edge(this._ptr, e.source, e.target);
        }
    }
    
    /**
     * Add a separation constraint
     * @param {number} dim - 0 for horizontal, 1 for vertical
     * @param {number} leftNode - Left/top node index
     * @param {number} rightNode - Right/bottom node index
     * @param {number} gap - Minimum gap
     * @param {boolean} isEquality - If true, creates equality constraint
     */
    addSeparationConstraint(dim, leftNode, rightNode, gap, isEquality = false) {
        this._checkDestroyed();
        colaModule._cola_add_separation_constraint(
            this._ptr, dim, leftNode, rightNode, gap, isEquality ? 1 : 0
        );
    }
    
    /**
     * Add an alignment constraint
     * @param {number} dim - 0 for horizontal, 1 for vertical
     * @param {number[]} nodeIds - Array of node indices to align
     * @returns {number} Alignment ID for use with distribution constraints
     */
    addAlignmentConstraint(dim, nodeIds) {
        this._checkDestroyed();
        
        // Convert JSArray to regular array if needed
        const arr = Array.isArray(nodeIds) ? nodeIds : Array.from(nodeIds);
        
        if (!arr || arr.length === 0) {
            console.warn('addAlignmentConstraint requires at least 1 node ID');
            return -1;
        }
        
        const ptr = colaModule._malloc(arr.length * 4);
        if (!ptr) {
            throw new Error('Failed to allocate memory for nodeIds');
        }
        
        let result = -1;
        try {
            const setValue = getSetValue();
            for (let i = 0; i < arr.length; i++) {
                // Convert JSNumber to number if needed
                const val = typeof arr[i] === 'object' ? Number(arr[i]) : arr[i];
                setValue(ptr + i * 4, val, 'i32');
            }
            
            result = colaModule._cola_add_alignment_constraint(this._ptr, dim, ptr, arr.length);
        } finally {
            colaModule._free(ptr);
        }
        return result;
    }
    
    /**
     * Add a distribution constraint (evenly distribute aligned nodes)
     * @param {number} dim - 0 for horizontal, 1 for vertical
     * @param {number[]} alignmentIds - Array of alignment IDs
     * @param {number} separation - Fixed separation (0 = auto)
     */
    addDistributionConstraint(dim, alignmentIds, separation = 0) {
        this._checkDestroyed();
        
        // Convert JSArray to regular array if needed
        const arr = Array.isArray(alignmentIds) ? alignmentIds : Array.from(alignmentIds);
        
        if (!arr || arr.length < 2) {
            console.warn('addDistributionConstraint requires at least 2 alignment IDs');
            return -1;
        }
        
        // Convert values
        const ids = arr.map(v => typeof v === 'object' ? Number(v) : v);
        
        // Validate alignment IDs
        for (const id of ids) {
            if (typeof id !== 'number' || id < 0 || !Number.isInteger(id)) {
                console.error('addDistributionConstraint: invalid alignment ID:', id);
                return -1;
            }
        }
        
        const byteSize = ids.length * 4;
        const ptr = colaModule._malloc(byteSize);
        if (!ptr) {
            throw new Error('Failed to allocate memory for alignmentIds');
        }
        
        let result = -1;
        try {
            const setValue = getSetValue();
            for (let i = 0; i < ids.length; i++) {
                setValue(ptr + i * 4, ids[i], 'i32');
            }
            
            result = colaModule._cola_add_distribution_constraint(this._ptr, dim, ptr, ids.length, separation);
            if (result < 0) {
                console.warn('addDistributionConstraint failed. Make sure alignment IDs are valid and dimension matches the alignments.');
            }
        } finally {
            colaModule._free(ptr);
        }
        return result;
    }
    
    /**
     * Add page boundary constraint (keep nodes within rectangle)
     * @param {number} xMin - Left boundary
     * @param {number} xMax - Right boundary
     * @param {number} yMin - Bottom boundary
     * @param {number} yMax - Top boundary
     * @param {number} weight - Constraint weight (default: 100)
     */
    addPageBoundary(xMin, xMax, yMin, yMax, weight = 100) {
        this._checkDestroyed();
        colaModule._cola_add_page_boundary(this._ptr, xMin, xMax, yMin, yMax, weight);
    }
    
    /**
     * Add boundary constraint (nodes on one side of a line)
     * @param {number} dim - 0 for horizontal, 1 for vertical
     * @param {number[]} nodeIds - Node indices
     * @param {number[]} offsets - Offsets (negative = left/above)
     * @returns {number} Boundary ID
     */
    addBoundaryConstraint(dim, nodeIds, offsets) {
        this._checkDestroyed();
        
        // Convert JSArray to regular array if needed
        const nodeArr = Array.isArray(nodeIds) ? nodeIds : Array.from(nodeIds);
        const offsetArr = Array.isArray(offsets) ? offsets : Array.from(offsets);
        
        if (!nodeArr || nodeArr.length === 0) {
            console.warn('addBoundaryConstraint requires at least 1 node');
            return -1;
        }
        
        const nodePtr = colaModule._malloc(nodeArr.length * 4);
        const offsetPtr = colaModule._malloc(offsetArr.length * 8);
        
        if (!nodePtr || !offsetPtr) {
            if (nodePtr) colaModule._free(nodePtr);
            if (offsetPtr) colaModule._free(offsetPtr);
            throw new Error('Failed to allocate memory');
        }
        
        let result = -1;
        try {
            const setValue = getSetValue();
            for (let i = 0; i < nodeArr.length; i++) {
                const nodeVal = typeof nodeArr[i] === 'object' ? Number(nodeArr[i]) : nodeArr[i];
                const offsetVal = typeof offsetArr[i] === 'object' ? Number(offsetArr[i]) : offsetArr[i];
                setValue(nodePtr + i * 4, nodeVal, 'i32');
                setValue(offsetPtr + i * 8, offsetVal, 'double');
            }
            
            result = colaModule._cola_add_boundary_constraint(this._ptr, dim, nodePtr, offsetPtr, nodeArr.length);
        } finally {
            colaModule._free(nodePtr);
            colaModule._free(offsetPtr);
        }
        return result;
    }
    
    /**
     * Add fixed-relative constraint (nodes maintain relative positions)
     * @param {number[]} nodeIds - Node indices
     * @param {boolean} fixedPosition - If true, group stays at current position
     */
    addFixedRelativeConstraint(nodeIds, fixedPosition = false) {
        this._checkDestroyed();
        
        // Convert JSArray to regular array if needed
        const arr = Array.isArray(nodeIds) ? nodeIds : Array.from(nodeIds);
        
        if (!arr || arr.length < 2) {
            console.warn('addFixedRelativeConstraint requires at least 2 nodes');
            return;
        }
        
        const ptr = colaModule._malloc(arr.length * 4);
        if (!ptr) {
            throw new Error('Failed to allocate memory for nodeIds');
        }
        
        try {
            const setValue = getSetValue();
            for (let i = 0; i < arr.length; i++) {
                const val = typeof arr[i] === 'object' ? Number(arr[i]) : arr[i];
                setValue(ptr + i * 4, val, 'i32');
            }
            
            colaModule._cola_add_fixed_relative_constraint(this._ptr, ptr, arr.length, fixedPosition ? 1 : 0);
        } finally {
            colaModule._free(ptr);
        }
    }
    
    /**
     * Add orthogonal edge constraint (edge endpoints aligned horizontally or vertically)
     * This ensures that the edge between two nodes is either horizontal or vertical
     * @param {number} dim - 0 for horizontal (same Y), 1 for vertical (same X)
     * @param {number} leftNode - Left/source node index
     * @param {number} rightNode - Right/target node index
     */
    addOrthogonalEdgeConstraint(dim, leftNode, rightNode) {
        this._checkDestroyed();
        colaModule._cola_add_orthogonal_edge_constraint(this._ptr, dim, leftNode, rightNode);
    }
    
    /**
     * Create a rectangular cluster
     * @param {number[]} nodeIds - Node indices in this cluster
     * @param {number} padding - Inner padding (default: 10)
     * @param {number} margin - Outer margin (default: 10)
     * @returns {number} Cluster ID (1-based, 0 = root)
     */
    createCluster(nodeIds, padding = 10, margin = 10) {
        this._checkDestroyed();
        
        // Convert JSArray to regular array if needed
        const arr = Array.isArray(nodeIds) ? nodeIds : Array.from(nodeIds);
        
        if (!arr || arr.length === 0) {
            console.warn('createCluster requires at least 1 node');
            return -1;
        }
        
        const ptr = colaModule._malloc(arr.length * 4);
        if (!ptr) {
            throw new Error('Failed to allocate memory for nodeIds');
        }
        
        let result = -1;
        try {
            const setValue = getSetValue();
            for (let i = 0; i < arr.length; i++) {
                const val = typeof arr[i] === 'object' ? Number(arr[i]) : arr[i];
                setValue(ptr + i * 4, val, 'i32');
            }
            
            result = colaModule._cola_create_rectangular_cluster(this._ptr, ptr, arr.length, padding, margin);
        } finally {
            colaModule._free(ptr);
        }
        return result;
    }
    
    /**
     * Add a cluster as child of another cluster
     * @param {number} parentId - Parent cluster ID (0 = root)
     * @param {number} childId - Child cluster ID
     */
    addChildCluster(parentId, childId) {
        this._checkDestroyed();
        colaModule._cola_add_child_cluster(this._ptr, parentId, childId);
    }
    
    /**
     * Set desired bounds for a cluster
     * @param {number} clusterId - Cluster ID
     * @param {number} xMin - Left boundary
     * @param {number} xMax - Right boundary
     * @param {number} yMin - Bottom boundary
     * @param {number} yMax - Top boundary
     */
    setClusterBounds(clusterId, xMin, xMax, yMin, yMax) {
        this._checkDestroyed();
        colaModule._cola_set_cluster_bounds(this._ptr, clusterId, xMin, xMax, yMin, yMax);
    }
    
    /**
     * Set desired position for a node (attraction point)
     * @param {number} nodeId - Node index
     * @param {number} x - Desired X position
     * @param {number} y - Desired Y position
     * @param {number} weight - Attraction weight (default: 1)
     */
    setDesiredPosition(nodeId, x, y, weight = 1) {
        this._checkDestroyed();
        colaModule._cola_set_desired_position(this._ptr, nodeId, x, y, weight);
    }
    
    /**
     * Clear all desired positions
     */
    clearDesiredPositions() {
        this._checkDestroyed();
        colaModule._cola_clear_desired_positions(this._ptr);
    }
    
    /**
     * Enable/disable overlap avoidance
     * @param {boolean} enable
     */
    setAvoidOverlaps(enable) {
        this._checkDestroyed();
        colaModule._cola_set_avoid_overlaps(this._ptr, enable ? 1 : 0);
    }
    
    /**
     * Set convergence parameters
     * @param {number} tolerance - Convergence tolerance (default: 0.0001)
     * @param {number} maxIterations - Maximum iterations (default: 100)
     */
    setConvergence(tolerance = 0.0001, maxIterations = 100) {
        this._checkDestroyed();
        colaModule._cola_set_convergence(this._ptr, tolerance, maxIterations);
    }
    
    /**
     * Enable/disable neighbour stress mode (better for large graphs)
     * @param {boolean} enable
     */
    setNeighbourStress(enable) {
        this._checkDestroyed();
        colaModule._cola_set_neighbour_stress(this._ptr, enable ? 1 : 0);
    }
    
    /**
     * Lock a node at a specific position
     * @param {number} nodeId - Node index
     * @param {number} x - X position
     * @param {number} y - Y position
     */
    lockNode(nodeId, x, y) {
        this._checkDestroyed();
        colaModule._cola_lock_node(this._ptr, nodeId, x, y);
    }
    
    /**
     * Unlock a previously locked node
     * @param {number} nodeId - Node index
     */
    unlockNode(nodeId) {
        this._checkDestroyed();
        colaModule._cola_unlock_node(this._ptr, nodeId);
    }
    
    /**
     * Clear all node locks
     */
    clearLocks() {
        this._checkDestroyed();
        colaModule._cola_clear_locks(this._ptr);
    }
    
    /**
     * Run the full layout algorithm
     */
    run() {
        this._checkDestroyed();
        colaModule._cola_run(this._ptr);
    }
    
    /**
     * Run a single iteration (for animation)
     * @returns {boolean} true if converged
     */
    tick() {
        this._checkDestroyed();
        return colaModule._cola_run_iteration(this._ptr) === 1;
    }
    
    /**
     * Make current configuration feasible
     */
    makeFeasible() {
        this._checkDestroyed();
        colaModule._cola_make_feasible(this._ptr);
    }
    
    /**
     * Get current stress value
     * @returns {number}
     */
    getStress() {
        this._checkDestroyed();
        return colaModule._cola_compute_stress(this._ptr);
    }
    
    /**
     * Get position of a single node
     * @param {number} nodeId
     * @returns {{x: number, y: number}}
     */
    getNodePosition(nodeId) {
        this._checkDestroyed();
        
        const xPtr = colaModule._malloc(8);
        const yPtr = colaModule._malloc(8);
        
        if (!xPtr || !yPtr) {
            if (xPtr) colaModule._free(xPtr);
            if (yPtr) colaModule._free(yPtr);
            throw new Error('Failed to allocate memory');
        }
        
        try {
            colaModule._cola_get_node_position(this._ptr, nodeId, xPtr, yPtr);
            
            const getValue = getGetValue();
            const x = getValue(xPtr, 'double');
            const y = getValue(yPtr, 'double');
            
            return { x, y };
        } finally {
            colaModule._free(xPtr);
            colaModule._free(yPtr);
        }
    }
    
    /**
     * Get all node positions
     * @returns {Float64Array} Array of [x0, y0, x1, y1, ...]
     */
    getAllPositions() {
        this._checkDestroyed();
        
        // Allocate buffer if needed
        if (!this._positionsBuffer) {
            this._positionsBuffer = colaModule._malloc(this._nodeCount * 2 * 8);
            if (!this._positionsBuffer) {
                throw new Error('Failed to allocate positions buffer');
            }
        }
        
        colaModule._cola_get_all_positions(this._ptr, this._positionsBuffer);
        
        // Copy to JS array
        const getValue = getGetValue();
        const result = new Float64Array(this._nodeCount * 2);
        for (let i = 0; i < this._nodeCount * 2; i++) {
            result[i] = getValue(this._positionsBuffer + i * 8, 'double');
        }
        
        return result;
    }
    
    /**
     * Get all positions as array of objects
     * @returns {Array<{x: number, y: number}>}
     */
    getPositions() {
        const flat = this.getAllPositions();
        const result = [];
        for (let i = 0; i < this._nodeCount; i++) {
            result.push({
                x: flat[i * 2],
                y: flat[i * 2 + 1]
            });
        }
        return result;
    }
    
    /**
     * Get number of nodes
     * @returns {number}
     */
    get nodeCount() {
        return this._nodeCount;
    }
    
    /**
     * Destroy the layout and free memory
     */
    destroy() {
        if (this._destroyed) return;
        
        if (this._positionsBuffer) {
            colaModule._free(this._positionsBuffer);
            this._positionsBuffer = null;
        }
        
        colaModule._cola_destroy_layout(this._ptr);
        this._ptr = null;
        this._destroyed = true;
    }
    
    _checkDestroyed() {
        if (this._destroyed) {
            throw new Error('Layout has been destroyed');
        }
    }
}

/**
 * Remove overlaps between rectangles (standalone function)
 * @param {Array<{x: number, y: number, width: number, height: number}>} rects
 * @returns {Array<{x: number, y: number, width: number, height: number}>}
 */
function removeOverlaps(rects) {
    if (!colaReady) {
        throw new Error('Cola not initialized. Call initCola() first.');
    }
    
    const count = rects.length;
    const ptr = colaModule._malloc(count * 4 * 8);
    
    // Copy input
    for (let i = 0; i < count; i++) {
        colaModule.setValue(ptr + (i * 4 + 0) * 8, rects[i].x, 'double');
        colaModule.setValue(ptr + (i * 4 + 1) * 8, rects[i].y, 'double');
        colaModule.setValue(ptr + (i * 4 + 2) * 8, rects[i].width, 'double');
        colaModule.setValue(ptr + (i * 4 + 3) * 8, rects[i].height, 'double');
    }
    
    colaModule._cola_remove_overlaps(ptr, count);
    
    // Copy output
    const result = [];
    for (let i = 0; i < count; i++) {
        result.push({
            x: colaModule.getValue(ptr + (i * 4 + 0) * 8, 'double'),
            y: colaModule.getValue(ptr + (i * 4 + 1) * 8, 'double'),
            width: rects[i].width,
            height: rects[i].height
        });
    }
    
    colaModule._free(ptr);
    
    return result;
}

// Export for use in browser/Dart
if (typeof window !== 'undefined') {
    window.initCola = initCola;
    window.isColaReady = isColaReady;
    window.ColaLayout = ColaLayout;
    window.removeOverlaps = removeOverlaps;
}

// Export for Node.js/module bundlers
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { initCola, isColaReady, ColaLayout, removeOverlaps };
}

/**
 * JavaScript wrapper for Cola WASM module
 * Provides a convenient API for use from Dart via js_interop
 */

let colaModule = null;
let colaReady = false;

/**
 * Initialize the Cola WASM module
 * Must be called before using any other functions
 * @returns {Promise<void>}
 */
async function initCola() {
    if (colaReady) return;
    
    colaModule = await ColaModule();
    colaReady = true;
    console.log('Cola WASM module initialized');
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
     */
    addAlignmentConstraint(dim, nodeIds) {
        this._checkDestroyed();
        
        // Allocate array in WASM memory
        const ptr = colaModule._malloc(nodeIds.length * 4);
        for (let i = 0; i < nodeIds.length; i++) {
            colaModule.setValue(ptr + i * 4, nodeIds[i], 'i32');
        }
        
        colaModule._cola_add_alignment_constraint(this._ptr, dim, ptr, nodeIds.length);
        
        colaModule._free(ptr);
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
        
        colaModule._cola_get_node_position(this._ptr, nodeId, xPtr, yPtr);
        
        const x = colaModule.getValue(xPtr, 'double');
        const y = colaModule.getValue(yPtr, 'double');
        
        colaModule._free(xPtr);
        colaModule._free(yPtr);
        
        return { x, y };
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
        }
        
        colaModule._cola_get_all_positions(this._ptr, this._positionsBuffer);
        
        // Copy to JS array
        const result = new Float64Array(this._nodeCount * 2);
        for (let i = 0; i < this._nodeCount * 2; i++) {
            result[i] = colaModule.getValue(this._positionsBuffer + i * 8, 'double');
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

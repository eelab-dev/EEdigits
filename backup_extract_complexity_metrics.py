import json

def analyze_complexity(filename):
    with open(filename, 'r') as f:
        stats = json.load(f)
    
    design = stats['design']
    
    # Define cell categories
    arith_types = ['$add', '$sub', '$mul', '$alu', '$shl', '$shr', '$lt', '$le', '$eq', '$ne', '$gt', '$ge']
    mux_types = ['$mux', '$pmux']
    ignored_types = ['$meminit_v2', '$meminit'] # Static data, not logic
    
    cells = design['num_cells_by_type']
    
    # Calculate Total Logic Cells (Denominator)
    # We subtract submodules and memory init cells to get actual gate/logic count
    #total_logic_cells = design['num_cells']
    #for cell_type, count in cells.items():
        #if cell_type in ignored_types or not cell_type.startswith('$'):
            #total_logic_cells -= count
    total_logic_cells = design['num_cells']
    for cell_type, count in cells.items():
        if cell_type in ignored_types:
            total_logic_cells -= count
        elif not cell_type.startswith('$'):
            total_logic_cells -= count   # remove submodules

    # Compute Counts
    da_count = sum(cells.get(t, 0) for t in arith_types)
    dm_count = sum(cells.get(t, 0) for t in mux_types)
    
    # Metrics
    da = da_count / total_logic_cells if total_logic_cells > 0 else 0
    dm = dm_count / total_logic_cells if total_logic_cells > 0 else 0
    
    # Word Size calculation (Excluding ports)
    int_wires = design['num_wires'] - design['num_ports']
    int_bits = design['num_wire_bits'] - design['num_port_bits']
    w = round(int_bits / int_wires) if int_wires > 0 else 1
    
    dr = design.get('num_memory_bits', 0)
    
    return {
        "D_A": round(da, 3),
        "D_M": round(dm, 3),
        "W": w,
        "D_R": dr,
        "Logic_Cells": total_logic_cells
    }
    
    print("\nComplexity Metrics")
    print("------------------")
    for k,v in metrics.items():
        print(f"{k}: {v}")
    
if __name__ == "__main__":
    import sys
    
    filename = sys.argv[1]
    metrics = analyze_complexity(filename)
    
    print(metrics)
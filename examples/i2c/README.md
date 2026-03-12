# I2C Case Study: File Guide

This folder contains an OpenCores I2C master that was prepared for formal verification.

## Core RTL used for formal

### `i2c_master_top_formal.v`
Top-level integration module.
- Exposes Wishbone interface and external I2C pad signals.
- Instantiates `i2c_master_byte_ctrl_formal`.
- Owns register map behavior (`prer`, `ctr`, `txr`, `cr`, `sr`) and interrupt generation.
- Main DUT used by the top-level formal harnesses.

### `i2c_master_byte_ctrl_formal.v`
Byte-level transaction controller.
- Converts top-level commands (`start`, `stop`, `read`, `write`) into bit-level operations.
- Contains byte shift register/counter logic and command sequencing FSM.
- Instantiates `i2c_master_bit_ctrl_formal`.

### `i2c_master_bit_ctrl_formal.v`
Bit-level bus controller.
- Generates low-level SCL/SDA timing behavior.
- Handles clock stretching interaction and arbitration-lost detection.
- Implements bus condition detection (start/stop) and bit transfer sub-steps.

### `i2c_master_defines.v`
Shared command encodings/macros used across the controller hierarchy.

---

## Formal artifacts (`formal/`)

### `formal/i2c_master_top_prove_formal.sv`
Top-level **prove harness** for safety properties.
- Uses symbolic host/environment inputs.
- Models open-drain line behavior for `scl_pad_i`/`sda_pad_i`.
- Asserts interface-level invariants (pad behavior, ack sanity, reset/IRQ constraints).
- Includes a few cover points to reduce vacuous proofs.

### `formal/i2c_master_top_prove.sby`
SymbiYosys configuration for the prove harness.
- Loads the `_formal.v` design hierarchy plus `i2c_master_top_prove_formal.sv`.
- Sets mode/engine/depth for proving assertions.

### `formal/i2c_master_top_cover_formal.sv`
Top-level **cover harness** for scenario reachability.
- Drives a scripted Wishbone sequence (prescaler/config/command flow).
- Tracks interrupt edges and transaction milestones.
- Uses `cover(...)` goals to produce representative traces.
- Retains basic safety assertions to avoid meaningless traces.

### `formal/i2c_master_top_cover.sby`
SymbiYosys configuration for the cover harness.
- Loads the same `_formal.v` hierarchy plus `i2c_master_top_cover_formal.sv`.
- Sets cover mode/depth for trace generation.

---

## Notes on legacy files

Current non-formalized legacy files are still present:
- `i2c_master_top.v`
- `i2c_master_byte_ctrl.v`
- `i2c_master_bit_ctrl.v`

These are retained only for comparison/history at this stage. The formal flow uses the `_formal.v` variants above.

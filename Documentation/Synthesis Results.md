# ANIDS VLSI Project

## Pipeline Manager Synthesis Report

This report summarizes the compiled `pipeline_manager` design loaded from
`pipeline_manager_compiled.ddc`.

### Tool And Library

| Item | Value |
| --- | --- |
| Tool | Synopsys Design Vision |
| Version | `W-2024.09-SP2` |
| Report date | `Tue Jun 2 15:40:22 2026` |
| Standard-cell library | `tsl18fs120_typ` |
| Operating conditions | `tsl18fs120_typ` |
| Wire-load model mode | `enclosed` |
| Design wire-load model | `16000` |

### Clock

| Clock | Period | Frequency | Waveform | Duty cycle |
| --- | ---: | ---: | --- | ---: |
| `clk` | `5.00 ns` | `200 MHz` | `{0 2.5}` | `50%` |

### Quality Of Results

| Metric | Value |
| --- | ---: |
| Levels of logic | `9.00` |
| Critical-path length | `3.72 ns` |
| Critical-path slack | `1.19 ns` |
| Critical-path clock period | `5.00 ns` |
| Total negative slack | `0.00 ns` |
| Violating setup paths | `0` |
| Worst hold violation | `0.00 ns` |
| Total hold violation | `0.00 ns` |
| Hold violations | `0` |

The design meets the reported setup and hold constraints.

### Cell Counts

| Metric | Value |
| --- | ---: |
| Hierarchical cells | `1` |
| Hierarchical ports | `14` |
| Leaf cells | `3151` |
| Buffers and inverters | `599` |
| Buffers | `392` |
| Inverters | `207` |
| Combinational cells | `2104` |
| Sequential cells | `1047` |
| Macros | `0` |

The hierarchical area report separately reports `422` ports, `3309` nets,
`3152` cells, and `34` references.

### Area

| Metric | Area |
| --- | ---: |
| Combinational area | `3203.250000` |
| Noncombinational area | `5240.750000` |
| Buffer and inverter area | `495.750000` |
| Macro and black-box area | `0.000000` |
| Net interconnect area | `2733.317460` |
| Total cell area | `8444.000000` |
| Total design area | `11177.317460` |

#### Hierarchical Area Distribution

| Hierarchical cell | Global cell area | Percent | Local combinational area | Local noncombinational area | Black-box area | Design |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `pipeline_manager` | `8444.0000` | `100.0%` | `3186.5000` | `5240.7500` | `0.0000` | `pipeline_manager` |
| `add_159` | `16.7500` | `0.2%` | `16.7500` | `0.0000` | `0.0000` | `pipeline_manager_DW01_inc_0_DW01_inc_4` |
| **Total** | | | **`3203.2500`** | **`5240.7500`** | **`0.0000`** | |

### Timing

The timing report used maximum-delay paths and an ideal clock network. A
fanout value of `1000` was used for high-fanout net delay calculations.

#### Ten Slowest Paths

| Startpoint | Endpoint | Data arrival time | Slack | Status |
| --- | --- | ---: | ---: | --- |
| `counter_reg[4]` | `output_layer_vector_reg[32]` | `3.72 ns` | `1.19 ns` | Met |
| `counter_reg[4]` | `output_layer_vector_reg[33]` | `3.72 ns` | `1.19 ns` | Met |
| `counter_reg[4]` | `output_layer_vector_reg[34]` | `3.72 ns` | `1.19 ns` | Met |
| `counter_reg[4]` | `output_layer_vector_reg[35]` | `3.72 ns` | `1.19 ns` | Met |
| `counter_reg[4]` | `output_layer_vector_reg[36]` | `3.72 ns` | `1.19 ns` | Met |
| `counter_reg[4]` | `output_layer_vector_reg[37]` | `3.72 ns` | `1.19 ns` | Met |
| `counter_reg[4]` | `loss_layer_vector_reg[37]` | `3.69 ns` | `1.22 ns` | Met |
| `counter_reg[4]` | `loss_layer_vector_reg[38]` | `3.69 ns` | `1.22 ns` | Met |
| `counter_reg[4]` | `loss_layer_vector_reg[39]` | `3.69 ns` | `1.22 ns` | Met |
| `counter_reg[4]` | `loss_layer_vector_reg[40]` | `3.69 ns` | `1.22 ns` | Met |

#### Worst Path Detail

The worst path is from `counter_reg[4]` to
`output_layer_vector_reg[32]`.

| Point | Incremental delay | Path delay |
| --- | ---: | ---: |
| `counter_reg[4]/Q (dfcrq1)` | `0.30 ns` | `0.30 ns` |
| `U1253/Z (xr02d1)` | `0.25 ns` | `0.55 ns` |
| `U41/ZN (nr04d1)` | `0.27 ns` | `0.82 ns` |
| `U1691/ZN (nd02d1)` | `0.19 ns` | `1.01 ns` |
| `U1602/ZN (inv0d0)` | `0.47 ns` | `1.48 ns` |
| `U1699/ZN (nd02d1)` | `0.19 ns` | `1.66 ns` |
| `U1254/ZN (inv0d0)` | `0.91 ns` | `2.57 ns` |
| `U1501/Z (buffd1)` | `0.33 ns` | `2.90 ns` |
| `U1377/Z (buffd1)` | `0.61 ns` | `3.51 ns` |
| `U551/Z (aor22d1)` | `0.20 ns` | `3.72 ns` |
| `output_layer_vector_reg[32]/D (dfcrq1)` | `0.00 ns` | `3.72 ns` |

The destination register setup time is `0.10 ns`, resulting in a required
arrival time of `4.90 ns`.

### Constraint Checks

`report_constraint -all_violators` reports no violated constraints.

The QoR report also reports:

| Metric | Value |
| --- | ---: |
| Total nets | `3295` |
| Nets with violations | `0` |
| Maximum-transition violations | `0` |
| Maximum-capacitance violations | `0` |

### Power Estimate

Power was estimated using low-effort zero-delay switching-activity
propagation. Primary inputs and sequential-cell outputs were not annotated, so
these values are estimates rather than workload-based power results.

| Metric | Power |
| --- | ---: |
| Cell internal power | `17.5913 mW` |
| Net switching power | `1.1625 mW` |
| Total dynamic power | `18.7538 mW` |
| Cell leakage power | `194.9753 nW` |

#### Power Groups

| Group | Internal power | Switching power | Leakage power | Total power | Percentage |
| --- | ---: | ---: | ---: | ---: | ---: |
| `io_pad` | `0.0000 mW` | `0.0000 mW` | `0.0000 pW` | `0.0000 mW` | `0.00%` |
| `memory` | `0.0000 mW` | `0.0000 mW` | `0.0000 pW` | `0.0000 mW` | `0.00%` |
| `black_box` | `0.0000 mW` | `0.0000 mW` | `0.0000 pW` | `0.0000 mW` | `0.00%` |
| `clock_network` | `16.9698 mW` | `0.0000 mW` | `0.0000 pW` | `16.9698 mW` | `90.49%` |
| `register` | `0.1843 mW` | `0.059722 mW` | `130800 pW` | `0.2441 mW` | `1.30%` |
| `sequential` | `0.0000 mW` | `0.0000 mW` | `0.0000 pW` | `0.0000 mW` | `0.00%` |
| `combinational` | `0.4372 mW` | `1.1028 mW` | `64171 pW` | `1.5401 mW` | `8.21%` |

### Reference Cells

| Reference | Unit area | Count | Total area | Attributes |
| --- | ---: | ---: | ---: | --- |
| `an02d1` | `1.250000` | `7` | `8.750000` | |
| `an03d1` | `1.500000` | `1` | `1.500000` | |
| `aoi21d1` | `1.250000` | `1` | `1.250000` | |
| `aoi22d1` | `1.500000` | `256` | `384.000000` | |
| `aoi31d1` | `1.500000` | `5` | `7.500000` | |
| `aon211d1` | `1.500000` | `2` | `3.000000` | |
| `aor21d1` | `1.750000` | `3` | `5.250000` | |
| `aor22d1` | `2.000000` | `512` | `1024.000000` | |
| `buffd1` | `1.000000` | `392` | `392.000000` | |
| `dfcrn1` | `5.250000` | `2` | `10.500000` | `n` |
| `dfcrq1` | `5.250000` | `533` | `2798.250000` | `n` |
| `dfnrq1` | `4.750000` | `512` | `2432.000000` | `n` |
| `inv0d0` | `0.500000` | `205` | `102.500000` | |
| `inv0d1` | `0.750000` | `1` | `0.750000` | |
| `nd02d0` | `1.000000` | `129` | `129.000000` | |
| `nd02d1` | `1.000000` | `7` | `7.000000` | |
| `nd03d1` | `1.250000` | `7` | `8.750000` | |
| `nd04d1` | `1.500000` | `1` | `1.500000` | |
| `nd12d1` | `1.250000` | `2` | `2.500000` | |
| `nr02d0` | `1.000000` | `6` | `6.000000` | |
| `nr02d1` | `1.000000` | `5` | `5.000000` | |
| `nr03d1` | `1.250000` | `5` | `6.250000` | |
| `nr04d1` | `1.500000` | `3` | `4.500000` | |
| `oai21d1` | `1.250000` | `7` | `8.750000` | |
| `oai22d1` | `1.500000` | `9` | `13.500000` | |
| `oai211d1` | `1.500000` | `1` | `1.500000` | |
| `oaim21d1` | `1.500000` | `2` | `3.000000` | |
| `oaim22d1` | `2.000000` | `513` | `1026.000000` | |
| `oan211d1` | `1.500000` | `2` | `3.000000` | |
| `or02d0` | `1.250000` | `2` | `2.500000` | |
| `or03d0` | `1.750000` | `1` | `1.750000` | |
| `pipeline_manager_DW01_inc_0_DW01_inc_4` | `16.750000` | `1` | `16.750000` | `h` |
| `xn02d1` | `2.750000` | `2` | `5.500000` | |
| `xr02d1` | `2.500000` | `8` | `20.000000` | |
| **Total** | | **`34` references** | **`8444.000000`** | |

The hierarchical incrementer `pipeline_manager_DW01_inc_0_DW01_inc_4`
contains:

| Reference | Unit area | Count | Total area | Attributes |
| --- | ---: | ---: | ---: | --- |
| `ah01d1` | `2.750000` | `5` | `13.750000` | `r` |
| `inv0d0` | `0.500000` | `1` | `0.500000` | |
| `xr02d1` | `2.500000` | `1` | `2.500000` | |
| **Total** | | **`3` references** | **`16.750000`** | |

Reference-cell attributes:

- `h`: hierarchical
- `n`: noncombinational
- `r`: removable

### Design Check

`check_design` reports one warning:

```text
Warning: In design 'pipeline_manager', port 'N[0]' is not connected to any nets. (LINT-28)
```

### Compile Statistics

| Stage | CPU time |
| --- | ---: |
| Resource sharing | `1.85 s` |
| Logic optimization | `5.94 s` |
| Mapping optimization | `4.22 s` |
| Overall compile time | `16.40 s` |
| Overall wall-clock time | `12.08 s` |

### Report Commands

The report was collected after loading the compiled DDC in Design Vision:

```tcl
source {ANIDS-VLSI-PROJECT/TCL Scripts/load_ddc.tcl}
report_qor
report_area -hierarchy
report_timing -max_paths 10
report_constraint -all_violators
report_power
report_reference -hierarchy
report_clocks
check_design
```

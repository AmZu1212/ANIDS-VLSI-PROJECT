# ANIDS Main Handshakes

This note summarizes the three main handshakes worth showing in the report. The layer-level enable/ready signals are useful for internal timing, but the larger system handshakes are clearer for explaining how the design is controlled, fed with data, and reports a result.

## APB Register Handshake

The APB interface is used to program the ANIDS register file. Software writes configuration values such as `N`, threshold, weights, biases, LUT contents, and `START_REG`. It can also read status/result values back from the register file.

The important APB signals are:

```text
pclk
presetN
paddr
pwdata
prdata
psel
penable
pwrite
pready
```

An APB transfer is active when `psel` is asserted. The setup phase has `psel=1` and `penable=0`. The access phase begins when `penable=1`. The transfer is accepted when `psel && penable && pready` is true. If `pwrite=1`, the transfer is a write using `pwdata`; if `pwrite=0`, the transfer is a read using `prdata`.

GTKWave preset:

```text
Outputs/gtkw/apb_register_handshake.gtkw
```

Markers in the APB preset:

```text
A = write setup for reg[1]
B = write access phase
C = write accepted, PREADY high
D = write cleanup

E = read setup for reg[1]
F = read access phase
G = read accepted, PREADY high and PRDATA valid
H = read cleanup
```

The write markers show `PWRITE=1`, `PADDR=1`, and `PWDATA=1`. The read markers show `PWRITE=0`, `PADDR=1`, and `PRDATA=1`. This makes both directions visible in the same APB waveform.

### APB Segment Explanation

The APB image shows one write transaction followed later by one read transaction. Both transactions target register address `1`, so the screenshot clearly shows that the same register can be written through `PWDATA` and later read back through `PRDATA`.

During the write transaction, marker `A` is the setup point. At this point `PSEL` goes high to select the ANIDS register file, `PWRITE` is high to indicate a write, `PADDR` is driven with `1`, and `PWDATA` is driven with `1`. `PENABLE` is still low during this setup phase. The important point is that address, data, and write direction are already stable before the access phase begins.

From marker `A` to marker `B`, the APB bus is in the setup phase. `PSEL` remains high, `PWRITE` remains high, and the address/data stay stable. At marker `B`, `PENABLE` goes high, which moves the bus transaction into the APB access phase.

From marker `B` to marker `C`, the APB access phase is active. The transfer is waiting for the register file response. At marker `C`, `PSEL`, `PENABLE`, and `PREADY` are all high at the same time. Since `PWRITE` is also high, this is the point where the write transfer is accepted and `PWDATA=1` is written to register `1`.

From marker `C` to marker `D`, the write transaction is completing. The bus remains valid briefly after acceptance, then at marker `D` the control signals are deasserted. `PSEL` goes low, `PENABLE` goes low, and `PWRITE` goes low, returning the APB interface to idle before the next transaction. `PREADY` may still be high at this cleanup point, but no APB transfer is active once `PSEL` and `PENABLE` are low.

The read transaction starts at marker `E`. Here `PSEL` goes high again and `PADDR` is set to `1`, but `PWRITE` remains low. This indicates a read from register `1`. As with the write setup phase, `PENABLE` is still low at the setup point.

From marker `E` to marker `F`, the APB read is in setup. The address is stable and the bus direction is read because `PWRITE=0`. At marker `F`, `PENABLE` goes high, starting the APB access phase for the read.

From marker `F` to marker `G`, the read access phase is active. At marker `G`, `PREADY` asserts and the read transfer is accepted. At this same point, `PRDATA` contains the value read from the register file. Since this read is from register `1`, and the earlier write stored the value `1`, the waveform shows `PRDATA=1`. `PWDATA` may still show an old value during the read, but it is ignored because `PWRITE=0`.

From marker `G` to marker `H`, the read is being cleaned up. The testbench captures the read data into `result_data`, then the APB controls are deasserted. At marker `H`, `PSEL` and `PENABLE` return low and the bus returns to idle. The captured `result_data` is now `1`, matching `PRDATA`.

## DMA Fetch Handshake

The DMA fetch handshake is how input vectors enter the ANIDS datapath. The core requests a new 128-bit vector, the memory fetch unit exposes readiness through `dma_ack`, and the external input side responds with `dma_valid` and `dma_data`. Once the vector is captured, `mfu_updated` pulses and the vector is pushed into the pipeline manager.

The important signals are:

```text
fetch_next_vector / core_fetch
dma_ack
dma_valid
dma_data
mfu_updated
mfu_features
```

GTKWave preset:

```text
Outputs/gtkw/dma_fetch_handshake.gtkw
```

Markers in the DMA/MFU preset:

```text
A = start_core goes high
B = core requests a vector with fetch_next_vector/core_fetch
C = MFU asserts dma_ack, meaning it is ready to receive the vector
D = testbench/source asserts dma_valid with dma_data
E = MFU asserts mfu_updated after capturing the vector
F = second fetch request
G = second dma_ack
```

The main transaction to show is:

```text
fetch_next_vector -> dma_ack -> dma_valid/dma_data -> mfu_updated
```

The second fetch/ack markers are included to show that the core continues requesting vectors while the pipeline is active.

### DMA/MFU Segment Explanation

The DMA/MFU image shows how an input vector is transferred into the ANIDS core. This is the most important data-entry handshake in the design. The core does not directly sample arbitrary DMA data; instead, the pipeline manager requests a vector, the memory fetch unit acknowledges readiness, and the external source provides a valid 128-bit vector.

Marker `A` shows `start_core` going high. This comes from the programmed `START_REG` bit. Once `start_core` is high, the pipeline manager is allowed to begin fetching vectors and advancing the pipeline. Before this point, the fetch path is idle.

From marker `A` to marker `B`, the core is transitioning from idle into active operation. The pipeline manager sees that the design has been started and prepares to request input data. At marker `B`, `fetch_next_vector`/`core_fetch` goes high. This is the core-side request asking the memory fetch unit for a new input vector.

From marker `B` to marker `C`, the memory fetch unit is responding to the request. The fetch request is only a request; the actual external data transfer does not happen until the MFU indicates it can accept data. At marker `C`, `dma_ack` goes high. This means the memory fetch unit is ready to receive a 128-bit vector from the external DMA/testbench side.

From marker `C` to marker `D`, the external source responds to the acknowledgment. The source sees `dma_ack` and then drives `dma_valid` high while placing the vector on `dma_data`. Marker `D` is the point where `dma_valid` is asserted with the vector data present. This is the valid-data phase of the handshake.

From marker `D` to marker `E`, the memory fetch unit captures the input vector. At marker `E`, `mfu_updated` pulses high and `dma_ack` has dropped. This pulse means the vector has been captured internally and `mfu_features` now contains the fetched 128-bit vector. In this waveform, `dma_valid` is still high at the exact `mfu_updated` marker because the testbench holds valid through that clock edge; it drops shortly afterward. The pipeline manager uses the `mfu_updated` pulse to push the vector into its internal FIFO.

Markers `F` and `G` show the beginning of a second fetch. At marker `F`, the core issues another `fetch_next_vector` request. At marker `G`, the MFU again asserts `dma_ack`. These markers are included to show that the fetch mechanism is not a one-time startup event; the core continues requesting new vectors while the pipeline is running, allowing streaming behavior.

The key sequence for the screenshot is:

```text
start_core -> fetch_next_vector -> dma_ack -> dma_valid/dma_data -> mfu_updated
```

In words, the system starts, the core asks for data, the MFU acknowledges readiness, the source provides valid data, and the MFU confirms that the vector was captured.

## Result Completion Handshake

The result completion path shows how a processed vector becomes a visible software result. When the loss function finishes, `loss_ready` pulses. The outlier detector then produces `core_done`, which also drives the top-level `done` output. The result status encoder writes the final status code into `RESULT_REG` through the hardware writeback path.

The important signals are:

```text
loss_ready
core_done / done
outlier_pulse
status_wr_en
status_wr_data
regfile_hw_wr_en
regfile_hw_wr_addr
regfile_hw_wr_data
RESULT_REG
```

GTKWave preset:

```text
Outputs/gtkw/result_completion_handshake.gtkw
```

Markers in the result completion preset:

```text
A = loss_ready pulses when the loss function finishes
B = core_done/done pulses after outlier detection
C = status_wr_en asserts for the hardware write to RESULT_REG
D = RESULT_REG updates with the final visible status value
```

The useful chain to show is:

```text
loss_ready -> core_done -> status_wr_en -> RESULT_REG update
```

This is the output-side completion path: the datapath finishes the loss calculation, the outlier detector reports completion, and the status encoder commits the final software-visible result.

### Result Completion Segment Explanation

The result completion image shows the final output-side control sequence after the pipeline has already processed a vector. The initial `start_core` signal is intentionally not marked in this preset because it occurs much earlier than the result event and would not appear cleanly in the same screenshot. Instead, the markers focus only on the final completion and status writeback sequence.

Marker `A` is the `loss_ready` pulse. This signal comes from the loss function and indicates that the loss accumulation for the current vector has finished. At this point, `loss_result` is valid inside the core and can be passed to the outlier detector. `loss_ready` is a short pulse, not a long-running state.

From marker `A` to marker `B`, the outlier detector consumes the completed loss result and compares it against the programmed threshold. At marker `B`, `core_done` pulses high. The top-level `done` output follows the same completion event, so this is the point where the core reports that the vector has finished processing. In this specific screenshot, `outlier_pulse` stays low, meaning the completed vector is not flagged as an anomaly.

From marker `B` to marker `C`, the completion pulse is handed to the result status encoder. The status encoder converts the core completion and outlier decision into the software-visible result code. At marker `C`, `status_wr_en` goes high. This is the hardware write-enable pulse into the register file. At the same time, the hardware write address is `RESULT_REG`, and `status_wr_data`/`regfile_hw_wr_data` carry the status value that will be stored.

From marker `C` to marker `D`, the hardware register write is committed. At marker `D`, `RESULT_REG` updates to the final visible status value. This is the value that software would later read through the APB interface. In the screenshot, this is the end of the result completion chain because the computation has been translated into a register-file status update.

The key sequence for the screenshot is:

```text
loss_ready -> core_done/done -> status_wr_en -> RESULT_REG update
```

In words, the loss function finishes, the core reports completion, the status encoder writes the result register, and the final status becomes visible to software.

# Hardware Watchdog for RISC-V Processor

## Overview

This project implements a hardware watchdog mechanism for a RISC-V processor.

The watchdog continuously monitors processor activity and automatically generates a reset signal when abnormal execution conditions or inactivity are detected.

## Objectives

- Improve processor reliability
- Detect processor hangs
- Enable automatic fault recovery
- Demonstrate watchdog integration with RISC-V systems

## Technologies Used

- Verilog HDL
- RISC-V Architecture
- Digital Design
- Computer Architecture

## Repository Structure

rtl/           -> Verilog source files

testbench/     -> Verification files

simulations/   -> Waveforms and outputs

images/        -> Block diagrams

docs/          -> Project documentation

## Applications

- Embedded Systems
- Fault Tolerant Computing
- Processor Monitoring
- Safety Critical Systems

## Future Improvements

- Configurable timeout values
- Interrupt-based warning system
- FPGA implementation

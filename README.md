# Ethernet-Controlled Audio Modulator on Nexys Video

FPGA-based real-time audio effects processor with an Ethernet-controlled dashboard.

This project implements an audio modulation and filtering engine on a Xilinx Artix-7 FPGA (Nexys Video board). Audio comes in over a 3.5 mm AUX cable, is processed in hardware, and is sent back out to headphones or speakers, while a Python dashboard over Ethernet lets you monitor and adjust the processing in real time.

---

## Table of contents

- [Features](#features)
- [Hardware overview](#hardware-overview)
- [System architecture](#system-architecture)
- [Implemented audio effects](#implemented-audio-effects)
- [Dashboard](#dashboard)
- [Getting started](#getting-started)
- [Repository structure](#repository-structure)
- [Possible extensions](#possible-extensions)
- [License](#license)

---

## Features

- Real-time audio processing at 48 kHz
- All DSP implemented in Verilog on an Artix-7 XC7A200T FPGA
- Control over Ethernet using an external PHY and a custom protocol
- Python dashboard (PyQt6) with:
  - Time-domain and frequency-domain views (FFT) for both channels
  - Sliders and controls for all modulation parameters
- Per-channel controls:
  - Volume
  - Programmable delay (up to about 2.7 seconds) via FIFO buffers
- Effects and filters:
  - Low-pass, high-pass, band-pass, band-stop
  - Tremolo (amplitude modulation)
  - Hard clipping distortion
  - Pure pass-through

---

## Hardware overview

The project targets the **Digilent Nexys Video** board with the following key components:

- **FPGA:** Xilinx Artix-7 XC7A200T-1SBG484C  
- **Audio codec:** ADAU1761 (Analog Devices) – ADC/DAC and analog front-end  
- **Ethernet PHY:** Realtek RTL8211E-VL – Gigabit Ethernet transceiver  
- **Clocks:**
  - 100 MHz main clock
  - 25 MHz for Ethernet
  - 30.72 MHz, 3.072 MHz, 12.288 MHz and 48 kHz for the audio path

### Suggested image

```markdown
![Nexys Video development board](docs/images/nexys-video-board.jpg)

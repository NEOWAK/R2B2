# R2B2

![GitHub stars](https://img.shields.io/github/stars/NEOWAK/R2B2?style=for-the-badge&logo=github) ![GitHub forks](https://img.shields.io/github/forks/NEOWAK/R2B2?style=for-the-badge&logo=github) ![GitHub issues](https://img.shields.io/github/issues/NEOWAK/R2B2?style=for-the-badge&logo=github) ![Last commit](https://img.shields.io/github/last-commit/NEOWAK/R2B2?style=for-the-badge&logo=github) ![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

## 📑 Table of Contents

- [Description](#description)
- [Screenshots](#screenshots)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Contributors](#contributors)
- [Contributing](#contributing)
- [License](#license)

## 📝 Description

R2B2 — Robot autonome ramasseur de balles de tennis

## 📸 Screenshots

![Capture d’écran du 2026 05 18 06 51 23](https://raw.githubusercontent.com/NEOWAK/R2B2/main/software/dashbord/Capture d’écran du 2026-05-18 06-51-23.png)

![adc mesure 5V](https://raw.githubusercontent.com/NEOWAK/R2B2/main/software/monitor/img/adc_mesure_5V.png)

![adc mesure paliers](https://raw.githubusercontent.com/NEOWAK/R2B2/main/software/monitor/img/adc_mesure_paliers.png)

![Capture d’écran du 2026 05 18 06 07 12](https://raw.githubusercontent.com/NEOWAK/R2B2/main/structure/pince/Capture d’écran du 2026-05-18 06-07-12.png)

![Capture d’écran du 2026 05 18 06 07 25](https://raw.githubusercontent.com/NEOWAK/R2B2/main/structure/pince/Capture d’écran du 2026-05-18 06-07-25.png)

![Capture d’écran du 2026 05 18 06 07 59](https://raw.githubusercontent.com/NEOWAK/R2B2/main/structure/pince/Capture d’écran du 2026-05-18 06-07-59.png)

## ⚡ Quick Start

```bash

# 1. Clone the repository
git clone https://github.com/NEOWAK/R2B2.git

# See the Development Setup section below
```

## 📁 Project Structure

```
.
├── LICENSE
├── docs
│   ├── cdc
│   │   ├── Rapport_CDC.pdf
│   │   └── Rapport_CDC.zip
│   ├── presentation
│   │   ├── R2B2.pdf
│   │   └── R2B2.pptx
│   └── rapport
│       ├── Rapport_PROJET.zip
│       └── Rapport_PROJETELEC_ROBOT_TENNIS.pdf
├── firmware
│   ├── esp32c3
│   │   ├── v0_1.ino.ino
│   │   └── v0_2.ino.ino
│   └── fpga
│       ├── driver
│       │   └── Motor_Controller.vhd
│       ├── pid
│       │   ├── adc0
│       │   │   ├── adc0.bsf
│       │   │   ├── adc0.cmp
│       │   │   ├── adc0.html
│       │   │   ├── adc0.ppf
│       │   │   ├── adc0.xml
│       │   │   ├── adc0_bb.v
│       │   │   ├── adc0_generation.rpt
│       │   │   ├── adc0_inst.v
│       │   │   ├── adc0_inst.vhd
│       │   │   └── synthesis
│       │   │       └── ...
│       │   ├── adc0.qsys
│       │   ├── adc0.sopcinfo
│       │   ├── adc_period.vhd
│       │   ├── baud_gen.vhd
│       │   ├── motor_controller.vhd
│       │   ├── top.vhd
│       │   ├── uart_framer.vhd
│       │   ├── uart_mux.vhd
│       │   ├── uart_rx.vhd
│       │   ├── uart_tx.vhd
│       │   ├── xor.qpf
│       │   ├── xor.qsf
│       │   ├── xor.qws
│       │   └── xor_assignment_defaults.qdf
│       ├── pince
│       │   └── pince_controlleur.vhd
│       └── ultrason
│           └── ultrason.vhd
├── hardware
│   ├── alimentation
│   │   ├── alimentation_0.heic
│   │   └── alimentation_1.heic
│   ├── cao
│   │   ├── pince.f3z
│   │   └── robot.f3z
│   └── pcb
│       ├── pads_layout.pdf
│       ├── pads_logic.pdf
│       ├── pcb.cir
│       ├── pcb.sch
│       ├── pcb_v1.pcb
│       └── pcb_v2.pcb
├── scripts
│   └── courbe_paramétrique.ggb
├── software
│   ├── dashbord
│   │   ├── Capture d’écran du 2026-05-18 06-51-23.png
│   │   └── dashboard.py
│   ├── detection
│   │   ├── esp32_camera.ino
│   │   └── modele_ia.zip
│   └── monitor
│       ├── img
│       │   ├── adc_mesure_5V.png
│       │   ├── adc_mesure_paliers.png
│       │   └── oscilo_mesure_5V.BMP
│       ├── monitor.py
│       └── monitor_v2.py
└── structure
    ├── pince
    │   ├── Capture d’écran du 2026-05-18 06-07-12.png
    │   ├── Capture d’écran du 2026-05-18 06-07-25.png
    │   ├── Capture d’écran du 2026-05-18 06-07-59.png
    │   ├── Capture d’écran du 2026-05-18 06-08-07.png
    │   ├── pince3D_01_square.jpg
    │   └── pinceo.jpg
    └── robot
        ├── robot_0.heic
        ├── robot_1.heic
        ├── robot_2.heic
        └── robot_v1.0_img0.jpg
```

## 👥 Contributors

Thanks to everyone who has contributed to this project:

<p align="left">
<a href="https://github.com/NEOWAK" title="NEOWAK"><img src="https://avatars.githubusercontent.com/u/180217825?v=4&s=64" width="64" height="64" alt="NEOWAK" style="border-radius:50%" /></a>
</p>

[See the full list of contributors →](https://github.com/NEOWAK/R2B2/graphs/contributors)

## 👥 Contributing

Contributions are welcome! Here's the standard flow:

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/NEOWAK/R2B2.git`
3. **Branch**: `git checkout -b feature/your-feature`
4. **Commit**: `git commit -m 'feat: add some feature'`
5. **Push**: `git push origin feature/your-feature`
6. **Open** a pull request

Please follow the existing code style and include tests for new behavior where applicable.

## 📜 License

This project is licensed under the **MIT** License.

---
*This README was generated with ❤️ by [ReadmeBuddy](https://readmebuddy.com)*

# Z3 Installation Guide

## Prerequisites
- `cmake` is required to configure the build. Install it with your package manager on Debian/Ubuntu systems:

```bash
sudo apt install cmake
```

## Clone the Repository
```bash
git clone https://github.com/Z3Prover/z3.git
cd z3
```

## Build and Install
```bash
mkdir build
cd build
cmake ../
make -j
sudo make install -j
```

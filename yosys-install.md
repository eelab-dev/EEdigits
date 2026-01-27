# Yosys install commands (Alpine)

Base packages:

```bash
sudo apk update
sudo apk add --no-cache build-base clang bison flex \
  readline-dev gawk tcl-dev libffi-dev git graphviz xdotool pkgconf python3 py3-pip zlib-dev
```

Note: `xdot` was unavailable in Alpine v3.22; `xdotool` is available and included above.

Install `click` system-wide via Alpine's package manager:

```bash
sudo apk add --no-cache py3-click
```

Yosys build fix for missing `FlexLexer.h` and Linux perf headers:

```bash
sudo apk add --no-cache flex-dev
```

Ensure `passes/cmds/linux_perf.cc` includes `#include <unistd.h>` so `read`, `write`, and `close` are declared on Linux. You can apply this automatically with:

```bash
sed -i '/#include <stdlib.h>/a #include <unistd.h>' /workspaces/digital-toolchains/yosys/passes/cmds/linux_perf.cc
```

Then install:

```bash
cd /workspaces/digital-toolchains/yosys
sudo make install
```


# DUNE SL7 Setup Helper

`duneSL7_setup.sh` is a single helper script for starting the FNAL SL7 container, setting up the DUNE software environment, optionally sourcing a local `protoduneana` development area, and preparing JUSTIN/Rucio access.

## Basic Usage

For the usual workflow:

```bash
./duneSL7_setup.sh start
```

This starts the normal SL7 container, runs the standard DUNE setup, then runs the JUSTIN setup.

To also source the local `protoduneana` environment:

```bash
./duneSL7_setup.sh start pana
```

## Start Modes

### Normal SL7 Container

```bash
./duneSL7_setup.sh start
```

Runs:

- normal SL7 container
- standard DUNE setup
- JUSTIN setup

### Normal SL7 Container With Local `protoduneana`

```bash
./duneSL7_setup.sh start pana
```

Runs:

- normal SL7 container
- standard DUNE setup
- local `protoduneana` setup
- JUSTIN setup

### Build SL7 Container

```bash
./duneSL7_setup.sh start build
```

Runs:

- build SL7 container
- standard DUNE setup
- JUSTIN setup

### Build SL7 Container With Local `protoduneana`

```bash
./duneSL7_setup.sh start build pana
```

Runs:

- build SL7 container
- standard DUNE setup
- local `protoduneana` setup
- JUSTIN setup

The order of `build` and `pana` does not matter:

```bash
./duneSL7_setup.sh start build pana
./duneSL7_setup.sh start pana build
```

## Manual Commands

### Enter Only the Normal SL7 Container

```bash
./duneSL7_setup.sh container
```

### Enter Only the Build SL7 Container

```bash
./duneSL7_setup.sh container build
```

### Run Only the DUNE Setup

Use this inside an already-open container:

```bash
source ./duneSL7_setup.sh setup
```

### Run DUNE Setup With Local `protoduneana`

Use this inside an already-open container:

```bash
source ./duneSL7_setup.sh setup pana
```

### Run Only the JUSTIN/Rucio Setup

Use this after the DUNE environment has already been set up:

```bash
source ./duneSL7_setup.sh justin
```

## Version Overrides

The script defines default DUNE software settings near the top:

```bash
DUNESW_VERSION_DEFAULT="v10_17_01d00"
DUNESW_QUALIFIER_DEFAULT="e26:prof"
```

To test a different DUNE software version without editing the script:

```bash
DUNESW_VERSION=v10_18_00 DUNESW_QUALIFIER=e26:prof ./duneSL7_setup.sh start pana
```

The local `protoduneana` setup path is built automatically from:

```bash
PROTODUNEANA_BASE
PROTODUNEANA_LOCAL_PRODUCTS_NAME
DUNESW_VERSION
DUNESW_QUALIFIER
```

For example, with the default values, the script looks for a path like:

```bash
/exp/dune/app/users/jairorod/protoDUNE/larmodule_singlep_protoduneana/localProducts_protoduneana_v10_17_01d00_e26_prof/setup
```

If the local products area has a different name, override it like this:

```bash
PROTODUNEANA_LOCAL_PRODUCTS_NAME=myana ./duneSL7_setup.sh start pana
```

## JUSTIN Authorization

If JUSTIN asks you to authorize the computer in a browser, the script stops before running token/Rucio commands that would fail.

After completing the browser authorization, run this in the same container shell:

```bash
justinsetupSL7_dune
```

## Compatibility Shortcuts

```bash
./duneSL7_setup.sh build
```

is equivalent to:

```bash
./duneSL7_setup.sh container build
```

```bash
./duneSL7_setup.sh pana
```

is equivalent to:

```bash
./duneSL7_setup.sh start pana
```

```bash
./duneSL7_setup.sh all
```

is the old name for:

```bash
./duneSL7_setup.sh start
```
```

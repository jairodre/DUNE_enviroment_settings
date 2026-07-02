#!/bin/bash

# Combined DUNE SL7 container, DUNE setup, and JUSTIN setup helper.
# Source this file inside an existing shell for persistent setup, or execute it
# with "start" to enter the container and run setup there automatically.

RED="\033[31m"
GREEN="\033[1;32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"
BOLD="\033[1m"

DUNE_SL7_SCRIPT="${BASH_SOURCE[0]}"
DUNE_SL7_APPTAINER="/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer"
DUNE_SL7_IMAGE="/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest"

# Default DUNE software configuration.
# Override DUNESW_VERSION or DUNESW_QUALIFIER before running this script to test
# a different release without editing the setup logic below.
DUNESW_VERSION_DEFAULT="v10_17_01d00"
DUNESW_QUALIFIER_DEFAULT="e26:prof"
PROTODUNEANA_BASE="${PROTODUNEANA_BASE:-/exp/dune/app/users/jairorod/protoDUNE/larmodule_singlep_protoduneana}"
PROTODUNEANA_LOCAL_PRODUCTS_NAME="${PROTODUNEANA_LOCAL_PRODUCTS_NAME:-protoduneana}"

# Return true when this file is sourced into the current shell.
# This lets the script either define functions for later use or run a command
# directly when executed as ./duneSL7_setup.sh.
_dune_sl7_is_sourced() {
    [[ "${BASH_SOURCE[0]}" != "$0" ]]
}

# Resolve this script path so the container can read the same file with
# "bash --rcfile". That is how the automatic "start" mode runs setup inside the
# new container shell instead of after the container exits.
_dune_sl7_script_path() {
    local source_path="${BASH_SOURCE[0]}"
    if command -v readlink >/dev/null 2>&1; then
        readlink -f "$source_path" 2>/dev/null && return 0
    fi
    printf "%s\n" "$source_path"
}

# Print the top-level help for the combined script.
# The public commands map to the old three scripts: container, setup, justin,
# plus "start" to run the full workflow automatically.
_dune_sl7_usage() {
    local name
    name="$(basename "$DUNE_SL7_SCRIPT")"
    echo -e "${YELLOW}Usage:${RESET} $name [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start [build] [pana]   Start a container, run DUNE setup, then run JUSTIN setup"
    echo "  container [build]      Enter the FNAL SL7 container only; no setup is run"
    echo "  setup [pana]           Run DUNE setup in the current shell/container"
    echo "  justin                 Run only the post-setup JUSTIN token/Rucio setup"
    echo "  functions              Load functions only when the file is sourced"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Options for start:"
    echo "  no option              Normal SL7 container + standard DUNE setup + JUSTIN"
    echo "  pana                   Normal SL7 container + setup with local protoduneana + JUSTIN"
    echo "  build                  Build SL7 container + standard DUNE setup + JUSTIN"
    echo "  build pana             Build SL7 container + setup with local protoduneana + JUSTIN"
    echo ""
    echo "Compatibility shortcuts:"
    echo "  build                Same as: container build"
    echo "  pana                 Same as: start pana"
    echo "  all                  Old name for: start"
    echo ""
    echo "Examples:"
    echo "  ./$name start"
    echo "  ./$name start pana"
    echo "  ./$name start build pana"
    echo "  DUNESW_VERSION=v10_18_00 DUNESW_QUALIFIER=e26:prof ./$name start pana"
    echo "  ./$name container build"
    echo "  source ~/$name setup pana"
    echo "  source ~/$name justin"
}

# Return a status code when sourced, or exit with it when executed.
# This keeps "source duneSL7_setup.sh setup" from closing the user's shell.
_dune_sl7_return_or_exit() {
    local code="${1:-0}"
    return "$code" 2>/dev/null || exit "$code"
}

# Choose the Apptainer bind list.
# Normal mode includes /pnfs/dune for data access; build mode keeps the smaller
# bind list from the old containerSL7_dune.sh script.
_dune_sl7_bind_paths() {
    local flavor="${1:-}"
    if [[ "$flavor" == "build" ]]; then
        printf "%s" "/cvmfs,/exp,/nashome,/opt,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf"
    else
        printf "%s" "/cvmfs,/exp,/nashome,/pnfs/dune,/opt,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf"
    fi
}

# Run "justin time" and detect the browser-authorization case.
# If JUSTIN asks to authorize this computer, return nonzero before later
# token/Rucio commands run and fail with confusing errors.
_dune_sl7_justin_time() {
    local output
    local status

    output="$(justin time 2>&1)"
    status=$?
    printf "%s\n" "$output"

    if ((status != 0)) || [[ "$output" == *"authorize this computer to run the justin command"* ]]; then
        echo -e "\n${YELLOW}JUSTIN authorization is required.${RESET}"
        echo "Finish the browser authorization, then run:"
        echo "  justinsetupSL7_dune"
        return 20
    fi

    return 0
}

# Convert a UPS qualifier like "e26:prof" to the localProducts suffix format
# used by MRB/local products directories, for example "e26_prof".
_dune_sl7_local_products_qualifier() {
    printf "%s" "$1" | tr ':' '_'
}

# Start the SL7 container.
# Without auto_setup, this uses the old "apptainer shell --shell=/bin/bash"
# behavior. With auto_setup, it uses "apptainer exec ... /bin/bash --rcfile
# this_script -i" so the container's new Bash reads this file and runs setup.
_dune_sl7_enter_shell() {
    local flavor="${1:-}"
    local auto_setup="${2:-}"
    local script_path bind_paths label

    script_path="$(_dune_sl7_script_path)"
    bind_paths="$(_dune_sl7_bind_paths "$flavor")"

    if [[ "$flavor" == "build" ]]; then
        label="FNAL SL7 ${GREEN}BUILD${RESET} container"
    else
        label="${BOLD}FNAL SL7 container${RESET}"
    fi

    printf "\n=== Entering %b ===\n\n" "$label"
    sleep 0.5

    if [[ -n "$auto_setup" ]]; then
        APPTAINERENV_DUNE_SL7_AUTO_SETUP="$auto_setup" \
        APPTAINERENV_DUNESW_VERSION="${DUNESW_VERSION:-$DUNESW_VERSION_DEFAULT}" \
        APPTAINERENV_DUNESW_QUALIFIER="${DUNESW_QUALIFIER:-$DUNESW_QUALIFIER_DEFAULT}" \
        APPTAINERENV_PROTODUNEANA_BASE="$PROTODUNEANA_BASE" \
        SINGULARITYENV_DUNE_SL7_AUTO_SETUP="$auto_setup" \
        SINGULARITYENV_DUNESW_VERSION="${DUNESW_VERSION:-$DUNESW_VERSION_DEFAULT}" \
        SINGULARITYENV_DUNESW_QUALIFIER="${DUNESW_QUALIFIER:-$DUNESW_QUALIFIER_DEFAULT}" \
        SINGULARITYENV_PROTODUNEANA_BASE="$PROTODUNEANA_BASE" \
        "$DUNE_SL7_APPTAINER" exec \
            -B "$bind_paths" --ipc --pid \
            "$DUNE_SL7_IMAGE" \
            /bin/bash --rcfile "$script_path" -i
    else
        "$DUNE_SL7_APPTAINER" shell --shell=/bin/bash \
            -B "$bind_paths" --ipc --pid \
            "$DUNE_SL7_IMAGE"
    fi
}

# Public replacement for containerSL7_dune.sh.
# Usage: containerSL7_dune [build]. With no argument it starts the normal SL7
# container; with "build" it starts the build container.
containerSL7_dune() {
    local var1="${1:-}"

    if [[ "$var1" == "-h" || "$var1" == "--help" ]]; then
        echo -e "${YELLOW}Usage:${RESET} containerSL7_dune [build]"
        echo ""
        echo "Options:"
        echo "  build    Enter FNAL SL7 build container"
        echo "  -h       Show this help message"
        return 0
    fi

    _dune_sl7_enter_shell "$var1"
}

# Public replacement for setupSL7_dune.sh.
# Sets UPS/DUNE/Rucio/MetaCat/JUSTIN environment, folder aliases, dunesw version,
# and optionally local protoduneana with "pana". It must run inside the shell
# that should keep the environment, so use "source ... setup" or "start".
setupSL7_dune() {
    local var1="${1:-}"
    local justin_status=0

    if [[ "$var1" == "-h" || "$var1" == "--help" ]]; then
        echo -e "${YELLOW}Usage:${RESET} setupSL7_dune [pana]"
        echo ""
        echo "Options:"
        echo "  pana     Source local protoduneana"
        echo "  -h       Show this help message"
        return 0
    fi

    # Pre-setup + rucio
    export UPS_OVERRIDE="-H Linux64bit+3.10-2.17"
    export IFDH_CP_MAXRETRIES=0
    export METACAT_SERVER_URL=https://metacat.fnal.gov:9443/dune_meta_prod/app
    export METACAT_AUTH_SERVER_URL=https://metacat.fnal.gov:8143/auth/dune

    # Aliases for common folders
    alias app='cd /exp/dune/app/users/$USER/; echo "$PWD"'
    alias data='cd /exp/dune/data/users/$USER/; echo "$PWD"'
    alias scratch='cd /pnfs/dune/scratch/users/$USER/; echo "$PWD"'
    alias persistent='cd /pnfs/dune/persistent/users/$USER/; echo "$PWD"'
    alias resilient='cd /pnfs/dune/resilient/users/$USER/; echo "$PWD"'

    # DUNE setup
    source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh

    export DUNESW_VERSION="${DUNESW_VERSION:-$DUNESW_VERSION_DEFAULT}"
    export DUNESW_QUALIFIER="${DUNESW_QUALIFIER:-$DUNESW_QUALIFIER_DEFAULT}"
    printf "\n=== Setting up ${GREEN}dunesw %s${RESET} with qualifier ${YELLOW}%s${RESET} ===\n\n" \
        "$DUNESW_VERSION" "$DUNESW_QUALIFIER"
    setup dunesw "$DUNESW_VERSION" -q "$DUNESW_QUALIFIER"

    htgettoken -a htvaultprod.fnal.gov -i dune
    setup metacat
    setup rucio
    setup justin
    _dune_sl7_justin_time
    justin_status=$?

    if [[ "$var1" == "pana" ]]; then
        local products_qualifier
        local protoduneana_setup

        products_qualifier="$(_dune_sl7_local_products_qualifier "$DUNESW_QUALIFIER")"
        protoduneana_setup="$PROTODUNEANA_BASE/localProducts_${PROTODUNEANA_LOCAL_PRODUCTS_NAME}_${DUNESW_VERSION}_${products_qualifier}/setup"

        if [[ ! -r "$protoduneana_setup" ]]; then
            echo -e "\n${RED}Missing local protoduneana setup:${RESET} $protoduneana_setup" >&2
            echo "Check DUNESW_VERSION, DUNESW_QUALIFIER, or build the matching local products area." >&2
            return 2
        fi

        source "$protoduneana_setup"
        mrbslp
        echo -e "\nLocal protoduneana sourced from: $MRB_TOP"
        echo -e "Version: $MRB_PROJECT_VERSION"
        echo -e "Qualifiers: $MRB_QUALS"
        echo -e ""
    fi

    source "$HOME/.bash_profile"
    return "$justin_status"
}

# Public replacement for justinsetupSL7_dune.sh.
# Rechecks JUSTIN authorization, obtains the JUSTIN token, switches to the
# readonly Rucio account, verifies Rucio, and moves to the DUNE app directory.
justinsetupSL7_dune() {
    echo -e "\n==========> justin time:"
    _dune_sl7_justin_time || return $?
    echo -e "==========> justin time END.\n"
    justin get-token || return $?

    export RUCIO_ACCOUNT=justinreadonly
    rucio whoami || return $?
    cd "/exp/dune/app/users/$USER/" && echo "$PWD"
}

# Full automatic workflow.
# Parses "build" and/or "pana", starts the selected container, and passes the
# requested setup mode through an environment variable into the container shell.
duneSL7_start() {
    local flavor=""
    local setup_arg="default"
    local arg

    for arg in "$@"; do
        case "$arg" in
            build)
                flavor="build"
                ;;
            pana)
                setup_arg="pana"
                ;;
            -h|--help)
                echo -e "${YELLOW}Usage:${RESET} duneSL7_start [build] [pana]"
                echo ""
                echo "Options:"
                echo "  build    Use the build SL7 container"
                echo "  pana     Source local protoduneana after DUNE setup"
                return 0
                ;;
            *)
                echo -e "${RED}Unknown option:${RESET} $arg" >&2
                return 2
                ;;
        esac
    done

    _dune_sl7_enter_shell "$flavor" "$setup_arg"
}

# Compatibility alias for the old automatic workflow name.
duneSL7_all() {
    duneSL7_start "$@"
}

# Runs only inside the container Bash started by duneSL7_start.
# It performs setupSL7_dune first, then runs justinsetupSL7_dune only if JUSTIN
# authorization is already valid; otherwise it leaves the shell open for manual
# browser authorization followed by "justinsetupSL7_dune".
_dune_sl7_run_auto_setup() {
    local setup_arg="${DUNE_SL7_AUTO_SETUP:-}"
    local setup_status=0

    # if [[ -r "$HOME/.bashrc" && -z "${DUNE_SL7_SKIP_USER_BASHRC:-}" ]]; then
    #     source "$HOME/.bashrc"
    # fi

    unset DUNE_SL7_AUTO_SETUP
    if [[ "$setup_arg" == "default" ]]; then
        setup_arg=""
    fi
    setupSL7_dune "$setup_arg"
    setup_status=$?
    if ((setup_status != 0)); then
        echo -e "\n${YELLOW}Automatic setup paused before JUSTIN token/Rucio setup.${RESET}"
        echo "After you complete authorization in the browser, run:"
        echo "  justinsetupSL7_dune"
        return "$setup_status"
    fi
    justinsetupSL7_dune
}

# Top-level command dispatcher.
# This maps script commands to functions and keeps compatibility shortcuts like
# "./duneSL7_setup.sh build" and "./duneSL7_setup.sh pana".
_dune_sl7_dispatch() {
    local command="${1:-container}"
    shift || true

    case "$command" in
        start)
            duneSL7_start "$@"
            ;;
        all)
            duneSL7_start "$@"
            ;;
        container)
            containerSL7_dune "$@"
            ;;
        setup)
            setupSL7_dune "$@"
            ;;
        justin)
            justinsetupSL7_dune "$@"
            ;;
        functions)
            return 0
            ;;
        build)
            containerSL7_dune build
            ;;
        pana)
            duneSL7_start pana
            ;;
        -h|--help|help)
            _dune_sl7_usage
            ;;
        *)
            echo -e "${RED}Unknown command:${RESET} $command" >&2
            _dune_sl7_usage >&2
            return 2
            ;;
    esac
}

if [[ -n "${DUNE_SL7_AUTO_SETUP:-}" ]]; then
    _dune_sl7_run_auto_setup
elif _dune_sl7_is_sourced; then
    if (($# > 0)); then
        _dune_sl7_dispatch "$@"
        _dune_sl7_return_or_exit $?
    fi
else
    _dune_sl7_dispatch "$@"
    exit $?
fi

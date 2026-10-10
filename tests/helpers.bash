# helpers.bash -- shared setup for wai BATS tests.
# Each test runs in an isolated HOME/XDG/TMPDIR; the repo under test is
# copied into BATS_TEST_TMPDIR so no real state is ever touched.

setup_env() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_CACHE_HOME="$HOME/.cache"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$TMPDIR"

    export OUT="$BATS_TEST_TMPDIR/out"
    mkdir -p "$OUT"

    export REPO="$BATS_TEST_TMPDIR/repo"
    cp -a "$BATS_TEST_DIRNAME/.." "$REPO"
    rm -rf "$REPO/.git"

    export WAI="$REPO/wai"
}

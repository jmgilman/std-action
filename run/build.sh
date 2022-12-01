#!/usr/bin/env bash

set -e

DRVS=$(jq -r '.|to_entries[]|select(.key|test("Drv$"))|select(.value|.!=null)|.value' <<< "$JSON")
declare -r DRVS

function calc_uncached() {
  echo "::group::Calculate Uncached Builds"

  declare -a unbuilt
  for drv in "${DRVS[@]}"; do
    # if the line grepped for doesn't show in the output, then there is nothing to build that isn't already cached
    if nix-store --realise "$drv" --dry-run 2>&1 | grep --silent 'derivations will be built:$'; then
      unbuilt+=("$drv")
    fi
  done

  echo "::debug::uncached paths: ${unbuilt[*]}"

  echo "uncached=${unbuilt[*]}" >> "$GITHUB_OUTPUT"

  echo "::endgroup::"
}


#shellcheck disable=SC2068
function build() {
  echo "::group::Nix Build"

  if [[ -n ${unbuilt[*]} ]]; then
    #shellcheck disable=SC2086
    echo "::debug::these paths will be built: $DRVS"

    nix-build --eval-store auto --store "$BUILDER" ${unbuilt[@]}
  else
    echo "Everything already cached, nothing to build."
  fi

  echo "::endgroup::"
}

calc_uncached

build

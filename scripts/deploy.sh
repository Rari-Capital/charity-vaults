#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy.
CharityVaultFactoryAddr=$(deploy CharityVaultFactory)
log "CharityVaultFactory deployed at:" $CharityVaultFactoryAddr
CharityVaultAddr=$(deploy CharityVault)
log "CharityVault deployed at:" $CharityVaultAddr
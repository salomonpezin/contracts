#!/bin/bash

if [ -z "$NETWORK" ]; then
	NETWORK_ARG="--network development"
else
	NETWORK_ARG="--network ${NETWORK}"
fi

yarn run truffle migrate --reset --compile-all $NETWORK_ARG

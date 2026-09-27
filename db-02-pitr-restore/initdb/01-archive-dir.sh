#!/usr/bin/env bash
# Runs once, on first container start: the WAL archive folder must exist before archiving starts.
mkdir -p /var/lib/postgresql/wal_archive

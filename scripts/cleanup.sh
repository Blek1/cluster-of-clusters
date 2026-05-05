#!/bin/bash
set -e

echo "Destroying all local Kubernetes clusters..."
kind delete cluster --all

echo "Wiping Karmada configurations..."
rm -rf "$HOME/.karmada"

echo " Cleanup Complete!"

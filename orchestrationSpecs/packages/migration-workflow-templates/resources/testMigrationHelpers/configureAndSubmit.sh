#!/bin/bash
#
# ============================================================================
# WARNING: TEST HELPER SCRIPT - SHOULD BE MOVED TO SEPARATE PACKAGE
# ============================================================================
# This script is part of the test workflow infrastructure and creates a
# logical dependency cycle:
# - migration-workflow-templates package provides workflow templates
# - workflow CLI (in migration console) depends on migration-workflow-templates
# - This test script depends on workflow CLI
#
# TODO: Move test workflows and helpers to a separate package (e.g.,
# migration-workflow-templates-test) to break this dependency cycle.
# ============================================================================
#
# This script runs workflow configure + submit via kubectl exec into the
# migration-console pod, ensuring the commands execute under the same
# service account (migration-console-access-role) that users use.

set -x

CONSOLE_POD="migration-console-0"
CONSOLE_CONTAINER="console"
# Read namespace from the pod's service account mount (available in every K8s pod).
# Falls back to 'ma' for local testing.
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null || echo "ma")

# Write error details to /dev/termination-log so Argo surfaces the reason, not just the exit code
fail() { echo "$1" | tee /dev/termination-log >&2; exit 1; }

echo "Building and submitting migration workflow via migration-console pod..."

# Decode base64 migration config from environment variable
echo "$MIGRATION_CONFIG_BASE64" | base64 -d > /tmp/migration_config.json

echo "Migration config contents:"
cat /tmp/migration_config.json

echo "Loading configuration from JSON..."
CONFIG_OUTPUT=$(cat /tmp/migration_config.json | kubectl -n "$NAMESPACE" exec -i "$CONSOLE_POD" -c "$CONSOLE_CONTAINER" -- workflow configure edit --stdin 2>&1) || fail "Configure failed: $CONFIG_OUTPUT"
echo "$CONFIG_OUTPUT"

# Submit workflow
echo "Submitting workflow..."
WORKFLOW_OUTPUT=$(kubectl -n "$NAMESPACE" exec "$CONSOLE_POD" -c "$CONSOLE_CONTAINER" -- workflow submit 2>&1) || fail "Submit failed: $WORKFLOW_OUTPUT"
echo "Workflow submit output: $WORKFLOW_OUTPUT"

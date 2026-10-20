#!/usr/bin/env bash
#
# validate_monitoring.sh - Validate the RHOAI "New" monitoring stack on the current OpenShift cluster.
#
# Checks:
#   Phase 1: Prerequisites (oc logged in)
#   Phase 2: DSCI - monitoring managementState=Managed, status=Ready
#   Phase 3: DSC  - exists and ComponentsReady=True
#   Phase 4: Monitoring namespace and expected pods Running
#   Phase 5: Child objects (MonitoringStack, TempoMonolithic, OpenTelemetryCollector)
#   Phase 6: PersesDatasource CRs available and not degraded
#
# Usage:   validation/scripts/validate_monitoring.sh
# Exit:    0 all checks pass, 1 one or more checks failed
#
# Requires: oc

set -uo pipefail

# --- colour helpers ---------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_step()  { echo -e "${BLUE}[STEP]${NC} $*"; }
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_pass()  { echo -e "${GREEN}[PASS]${NC} $*"; PASSED=$((PASSED + 1)); }
log_fail()  { echo -e "${RED}[FAIL]${NC} $*"; FAILED=$((FAILED + 1)); }

PASSED=0
FAILED=0

# ---------------------------------------------------------------------------
# Phase 1: Prerequisites
# ---------------------------------------------------------------------------
log_step "Phase 1: Prerequisites"

if ! command -v oc &>/dev/null; then
    echo "error: oc is required but not installed." >&2
    exit 2
fi

if ! oc whoami &>/dev/null; then
    echo "error: not logged into an OpenShift cluster - run 'oc login' first." >&2
    exit 2
fi
log_info "Connected to: $(oc whoami --show-server)"

# ---------------------------------------------------------------------------
# Phase 2: DSCI
# ---------------------------------------------------------------------------
log_step "Phase 2: DataScienceClusterInitialization (DSCI)"

DSCI_NAME="default-dsci"

if ! oc get dsci "$DSCI_NAME" &>/dev/null; then
    log_fail "DSCI '$DSCI_NAME' not found"
else
    log_pass "DSCI '$DSCI_NAME' exists"

    DSCI_PHASE=$(oc get dsci "$DSCI_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [ "$DSCI_PHASE" = "Ready" ]; then
        log_pass "DSCI status.phase=$DSCI_PHASE"
    else
        log_fail "DSCI status.phase=$DSCI_PHASE (expected Ready)"
    fi

    MGMT_STATE=$(oc get dsci "$DSCI_NAME" -o jsonpath='{.spec.monitoring.managementState}' 2>/dev/null || echo "")
    if [ "$MGMT_STATE" = "Managed" ]; then
        log_pass "DSCI spec.monitoring.managementState=Managed"
    else
        log_fail "DSCI spec.monitoring.managementState='$MGMT_STATE' (expected Managed)"
    fi

    MONITORING_NS=$(oc get dsci "$DSCI_NAME" -o jsonpath='{.spec.monitoring.namespace}' 2>/dev/null || echo "")
    if [ -n "$MONITORING_NS" ]; then
        log_pass "DSCI spec.monitoring.namespace=$MONITORING_NS"
    else
        log_fail "DSCI spec.monitoring.namespace is not set"
        MONITORING_NS="redhat-ods-monitoring"
        log_warn "Falling back to $MONITORING_NS for remaining checks"
    fi
fi

# ---------------------------------------------------------------------------
# Phase 3: DSC
# ---------------------------------------------------------------------------
log_step "Phase 3: DataScienceCluster (DSC)"

DSC_NAME="default-dsc"

if ! oc get dsc "$DSC_NAME" &>/dev/null; then
    log_fail "DSC '$DSC_NAME' not found"
else
    log_pass "DSC '$DSC_NAME' exists"

    COMPONENTS_READY=$(oc get dsc "$DSC_NAME" \
        -o jsonpath='{.status.conditions[?(@.type=="ComponentsReady")].status}' 2>/dev/null || echo "Unknown")
    if [ "$COMPONENTS_READY" = "True" ]; then
        log_pass "DSC ComponentsReady=True"
    else
        log_fail "DSC ComponentsReady=$COMPONENTS_READY (expected True)"
    fi
fi

# ---------------------------------------------------------------------------
# Phase 4: Monitoring namespace and pod health
# ---------------------------------------------------------------------------
log_step "Phase 4: Monitoring namespace and pods (namespace: $MONITORING_NS)"

if ! oc get namespace "$MONITORING_NS" &>/dev/null; then
    log_fail "Monitoring namespace '$MONITORING_NS' does not exist - is the monitoring stack deployed?"
else
    log_pass "Namespace '$MONITORING_NS' exists"

    # Helper: count Running pods matched by a label selector.
    # grep -c already outputs "0" on no match; || true swallows the non-zero exit.
    running_pods() {
        oc get pods -n "$MONITORING_NS" -l "$1" --no-headers 2>/dev/null \
            | grep -c "Running" || true
    }

    # Alertmanager
    AM_RUNNING=$(running_pods 'app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=data-science-monitoringstack')
    if [ "${AM_RUNNING:-0}" -ge 1 ]; then
        log_pass "AlertManager pods running ($AM_RUNNING)"
    else
        log_fail "AlertManager pods not running (label: app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=data-science-monitoringstack)"
    fi

    # Prometheus
    PROM_RUNNING=$(running_pods 'app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=data-science-monitoringstack')
    if [ "${PROM_RUNNING:-0}" -ge 1 ]; then
        log_pass "Prometheus pods running ($PROM_RUNNING)"
    else
        log_fail "Prometheus pods not running (label: app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=data-science-monitoringstack)"
    fi

    # OpenTelemetry Collector
    OTEL_RUNNING=$(running_pods 'app.kubernetes.io/name=data-science-collector-collector')
    if [ "${OTEL_RUNNING:-0}" -ge 1 ]; then
        log_pass "OpenTelemetry Collector pods running ($OTEL_RUNNING)"
    else
        log_fail "OpenTelemetry Collector pods not running (label: app.kubernetes.io/name=data-science-collector-collector)"
    fi

    # Tempo
    TEMPO_RUNNING=$(running_pods 'app.kubernetes.io/name=tempo-monolithic,app.kubernetes.io/instance=data-science-tempomonolithic')
    if [ "${TEMPO_RUNNING:-0}" -ge 1 ]; then
        log_pass "Tempo pods running ($TEMPO_RUNNING)"
    else
        log_fail "Tempo pods not running (label: app.kubernetes.io/name=tempo-monolithic,app.kubernetes.io/instance=data-science-tempomonolithic)"
    fi

    # Thanos Querier
    THANOS_RUNNING=$(running_pods 'app.kubernetes.io/part-of=ThanosQuerier')
    if [ "${THANOS_RUNNING:-0}" -ge 1 ]; then
        log_pass "Thanos Querier pods running ($THANOS_RUNNING)"
    else
        log_fail "Thanos Querier pods not running (label: app.kubernetes.io/part-of=ThanosQuerier)"
    fi
fi

# ---------------------------------------------------------------------------
# Phase 5: Child objects
# ---------------------------------------------------------------------------
log_step "Phase 5: Child objects"

# Cluster Observability Operator - must be in openshift-cluster-observability-operator,
# not openshift-operators; the RHOAI perses-operator-access NetworkPolicy only admits
# that namespace, so a COO installed elsewhere breaks the Perses path silently.
COO_NS="openshift-cluster-observability-operator"
COO_PHASE=$(oc get csv -n "$COO_NS" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null \
    | grep '^cluster-observability-operator' | awk '{print $2}')
if [ "$COO_PHASE" = "Succeeded" ]; then
    log_pass "Cluster Observability Operator CSV Succeeded (namespace: $COO_NS)"
elif [ -z "$COO_PHASE" ]; then
    log_fail "Cluster Observability Operator CSV not found in $COO_NS (installing into openshift-operators breaks the Perses path)"
else
    log_fail "Cluster Observability Operator CSV phase=$COO_PHASE (expected Succeeded)"
fi

# MonitoringStack
if oc get monitoringstack data-science-monitoringstack -n "$MONITORING_NS" &>/dev/null; then
    MS_AVAILABLE=$(oc get monitoringstack data-science-monitoringstack -n "$MONITORING_NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
    if [ "$MS_AVAILABLE" = "True" ]; then
        log_pass "MonitoringStack 'data-science-monitoringstack' Available=True"
    else
        log_fail "MonitoringStack 'data-science-monitoringstack' Available=$MS_AVAILABLE"
    fi
else
    log_fail "MonitoringStack 'data-science-monitoringstack' not found in $MONITORING_NS"
fi

# TempoMonolithic
if oc get tempomonolithic data-science-tempomonolithic -n "$MONITORING_NS" &>/dev/null; then
    TEMPO_READY=$(oc get tempomonolithic data-science-tempomonolithic -n "$MONITORING_NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [ "$TEMPO_READY" = "True" ]; then
        log_pass "TempoMonolithic 'data-science-tempomonolithic' Ready=True"
    else
        log_fail "TempoMonolithic 'data-science-tempomonolithic' Ready=$TEMPO_READY"
    fi
else
    log_fail "TempoMonolithic 'data-science-tempomonolithic' not found in $MONITORING_NS"
fi

# OpenTelemetryCollector
if oc get opentelemetrycollector data-science-collector -n "$MONITORING_NS" &>/dev/null; then
    OTEL_READY=$(oc get opentelemetrycollector data-science-collector -n "$MONITORING_NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [ "$OTEL_READY" = "True" ]; then
        log_pass "OpenTelemetryCollector 'data-science-collector' Ready=True"
    else
        log_fail "OpenTelemetryCollector 'data-science-collector' Ready=$OTEL_READY"
    fi
else
    log_fail "OpenTelemetryCollector 'data-science-collector' not found in $MONITORING_NS"
fi

# ---------------------------------------------------------------------------
# Phase 6: PersesDatasource CRs
# ---------------------------------------------------------------------------
log_step "Phase 6: PersesDatasource CRs"

# Perses server instance - created by the RHOAI operator; dashboards cannot be
# pushed to it until it exists.
if oc get perses data-science-perses -n "$MONITORING_NS" &>/dev/null; then
    log_pass "Perses server 'data-science-perses' exists"
else
    log_fail "Perses server 'data-science-perses' not found in $MONITORING_NS"
fi

check_perses_datasource() {
    local name="$1"
    if ! oc get persesdatasource "$name" -n "$MONITORING_NS" &>/dev/null; then
        log_fail "PersesDatasource '$name' not found in $MONITORING_NS"
        return
    fi
    log_pass "PersesDatasource '$name' exists"

    local available degraded
    available=$(oc get persesdatasource "$name" -n "$MONITORING_NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
    degraded=$(oc get persesdatasource "$name" -n "$MONITORING_NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Degraded")].status}' 2>/dev/null || echo "Unknown")

    if [ "$available" = "True" ]; then
        log_pass "PersesDatasource '$name' Available=True"
    else
        log_fail "PersesDatasource '$name' Available=$available (expected True)"
    fi

    if [ "$degraded" = "False" ]; then
        log_pass "PersesDatasource '$name' Degraded=False"
    else
        log_fail "PersesDatasource '$name' Degraded=$degraded (expected False)"
    fi
}

check_perses_datasource "cluster-prometheus-datasource"
check_perses_datasource "data-science-prometheus-datasource"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================="
echo "Monitoring Stack Validation Summary"
echo "========================================="
echo "Passed: ${PASSED}"
echo "Failed: ${FAILED}"
if [ "$FAILED" -gt 0 ]; then
    echo "Status: SOME CHECKS FAILED"
else
    echo "Status: ALL CHECKS PASSED"
fi
echo "========================================="

[ "$FAILED" -eq 0 ]

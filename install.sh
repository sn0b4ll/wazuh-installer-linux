#!/usr/bin/env bash
# =============================================================================
# install.sh -- Full Wazuh agent installer for Linux
#
# Installs the Wazuh agent, auditd with a hardened ruleset, and LAUREL on any
# mainstream Linux distribution. Run with --help for usage.
#
# Usage:
#   sudo bash install.sh --manager <manager-ip> [OPTIONS]
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${REPO_DIR}/lib/common.sh"
# shellcheck source=lib/vars.sh
source "${REPO_DIR}/lib/vars.sh"
# shellcheck source=lib/detect.sh
source "${REPO_DIR}/lib/detect.sh"
# shellcheck source=lib/install-wazuh-agent.sh
source "${REPO_DIR}/lib/install-wazuh-agent.sh"
# shellcheck source=lib/install-auditd.sh
source "${REPO_DIR}/lib/install-auditd.sh"
# shellcheck source=laurel/install-laurel.sh
source "${REPO_DIR}/laurel/install-laurel.sh"

# ---- Pre-flight ----
parse_args "$@"
[[ $EUID -eq 0 ]] || die "This script must be run as root."
validate_vars
export_wazuh_vars

# ---- OS detection ----
section "OS Detection"
detect_os

# ---- Header ----
echo
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}  Wazuh Agent Installer${NC}"
echo -e "  Manager    : ${WAZUH_MANAGER}"
echo -e "  Agent name : ${WAZUH_AGENT_NAME:-$(hostname)}"
if [[ -n "${WAZUH_AGENT_GROUP:-}" ]]; then echo -e "  Groups     : ${WAZUH_AGENT_GROUP}"; fi
if [[ -n "${WAZUH_VERSION:-}"      ]]; then echo -e "  Version    : ${WAZUH_VERSION}"; fi
if [[ -n "${PACKAGE_PATH:-}"       ]]; then echo -e "  Package    : ${PACKAGE_PATH}  (offline install)"; fi
if [[ "${DRY_RUN}" == "true"       ]]; then echo -e "  ${YELLOW}Mode       : DRY RUN — no changes will be made${NC}"; fi
echo -e "${BOLD}================================================================${NC}"
echo

# ---- Install phases ----
install_wazuh_agent

if [[ "${SKIP_AUDITD}" != "true" ]]; then
    install_auditd
else
    info "Skipping auditd (--skip-auditd)"
fi

if [[ "${SKIP_LAUREL}" != "true" ]]; then
    install_laurel
else
    info "Skipping LAUREL (--skip-laurel)"
fi

# ---- Post-install verification ----
section "Verification"

if [[ "${DRY_RUN}" != "true" ]]; then
    if systemctl is-active --quiet wazuh-agent; then
        ok "wazuh-agent  : running"
    else
        warn "wazuh-agent not active — check: journalctl -u wazuh-agent"
    fi

    if [[ "${SKIP_AUDITD}" != "true" ]]; then
        if systemctl is-active --quiet auditd; then
            ok "auditd       : running"
        else
            warn "auditd not active"
        fi
    fi

    if [[ "${SKIP_LAUREL}" != "true" ]]; then
        if pgrep -x laurel >/dev/null 2>&1; then
            ok "laurel       : running  (pid $(pgrep -x laurel | head -1))"
        else
            warn "LAUREL process not detected — verify with: pgrep -a laurel"
        fi
    fi
else
    ok "[DRY-RUN] All phases would complete here"
fi

echo
echo -e "${BOLD}================================================================${NC}"
echo -e "${GREEN}${BOLD}  Installation complete.${NC}"
echo -e "${BOLD}================================================================${NC}"

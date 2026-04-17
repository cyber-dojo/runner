package policy

import rego.v1

max_days_by_severity := {
    "critical": 3,
    "high":     7,
    "medium":   30,
    "low":      90,
}

default allow = false

# rule-1: vulnerability age exceeds the threshold for its severity
violations contains msg if {
    some trail in input.trails
    vuln := trail.compliance_status.attestations_statuses["snyk"].attestation_data
    now_secs := time.now_ns() / 1000000000
    age_days := (now_secs - vuln.first_seen_ts) / 86400
    max := max_days_by_severity[vuln.severity]
    age_days > max
    msg := sprintf(
        "trail '%v': %v severity vuln age %d days exceeds %d day limit for severity %v",
        [trail.name, vuln.id, age_days, max, vuln.severity],
    )
}

# rule-2: vulnerability has an ignore entry whose expiry is in the past
violations contains msg if {
    some trail in input.trails
    vuln := trail.compliance_status.attestations_statuses["snyk"].attestation_data
    vuln.ignore_expires_exists == true
    now_secs := time.now_ns() / 1000000000
    vuln.ignore_expires_ts < now_secs
    msg := sprintf(
        "trail '%v': %v snyk ignore entry expired at %v",
        [trail.name, vuln.id, vuln.ignore_expires],
    )
}

allow if {
    count(violations) == 0
}

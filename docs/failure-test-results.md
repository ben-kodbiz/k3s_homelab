# Failure Test Results — Cluster b

**Date**: 2026-09-04T04:49:58+08:00
**API**: 10.21.20.11

| Test | Result |
|------|--------|
| Server node failure — cluster recovered with 6/6 nodes | PASS |
| Worker node failure — cluster recovered with 6/6 nodes | PASS |
| Pod failure — pods recreated (3 running) | PASS |
| Deployment failure — bad image detected (2 pods in error) | PASS |
| Cilium restart — agents recovered, nodes still Ready | PASS |
| DNS failure — CoreDNS recovered, resolution works | PASS |
| Storage — PVC bound, survived pod delete/recreate | PASS |

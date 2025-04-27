# SSL Certificate Generator Performance Summary

## Test Environment
- Date: Sat Apr 26 09:58:33 PM HDT 2025
- OpenSSL Version: OpenSSL 3.0.15 3 Sep 2024 (Library: OpenSSL 3.0.15 3 Sep 2024)
- System: Linux toluca.local 6.12.20+rpt-rpi-2712 #1 SMP PREEMPT Debian 1:6.12.20-1+rpt1~bpo12+1 (2025-03-19) aarch64 GNU/Linux

## Certificate Generation Performance

### Single Certificate Generation
| Test | Duration (seconds) |
|------|-------------------|
| single_cert_gen_1: | 0.451 |
| single_cert_gen_2: | 1.014 |
| single_cert_gen_3: | 0.413 |
| single_cert_gen_4: | 0.734 |
| single_cert_gen_5: | 1.132 |

**Average Time:** 0.749 seconds

### Parallel Generation Performance
| Test | Duration (seconds) | Certificates |
|------|-------------------|--------------|
| parallel_cert_gen_1: | 1.139 | 5 |
| parallel_cert_gen_2: | 1.052 | 5 |
| parallel_cert_gen_3: | 1.070 | 5 |

**Average Time (5 certificates):** 1.087 seconds
**Average Time per Certificate:** 0.217 seconds

### Load Testing Performance
| Test | Duration (seconds) |
|------|-------------------|
| sequential_load_1: | 0.490 |
| sequential_load_2: | 0.502 |
| sequential_load_3: | 0.832 |
| sequential_load_4: | 0.756 |
| sequential_load_5: | 1.122 |
| sequential_load_6: | 0.547 |
| sequential_load_7: | 0.591 |
| sequential_load_8: | 0.695 |
| sequential_load_9: | 0.445 |
| sequential_load_10: | 0.749 |

**Total Load Test Time:** 6.791 seconds
**Certificate Generation Rate:** 1.473 certificates/second

## Performance Statistics

| Metric | Value |
|--------|-------|
| Single Certificate Average | 0.749 s |
| Parallel Generation Average (5 certs) | 1.087 s |
| Load Test Total (10 certs) | 6.791 s |
| Certificate Generation Rate | 1.473 certs/second |

## Resource Usage

| Resource | Usage |
|----------|-------|
| CPU Usage | 0.0% |
| Memory Usage | 72% |
| Disk Space | 48% |

## Conclusions

1. Certificate Generation Speed:
   - Single certificate: 0.749 seconds
   - Parallel (5 certs): 1.087 seconds (1.473 certs/second)

2. Recommendations:
   - Optimal batch size: 5 certificates
   - Recommended parallel processes: 4
   - Buffer time for certificate operations: 1.497 seconds

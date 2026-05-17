# Q1 — CONSTRUCT ce:workedWith — Run Summary

| Metric | Value |
|---|---:|
| Source KG size (deployed `cineexplorer` dataset) | 1,611,676 triples |
| Persons with `ce:workedFor` | 38,067 |
| Distinct works in the slice | 5,000 |
| **Output triples emitted by `CONSTRUCT`** | **1,679,610** |
| Growth factor vs. source KG | ≈ 1.04× |
| Output TTL (gitignored, ~87 MB) | `sparql/results/q1_workedwith.ttl` |

The output is the symmetric closure of the collaboration relation over the
shared-title self-join on `ce:workedFor`: both `(A, B)` and `(B, A)` are
emitted, so the resulting graph is closed under symmetry without a reasoner.
The `FILTER(?p1 != ?p2)` clause drops self-loops.

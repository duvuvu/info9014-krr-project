# SHACL Validation Summary — CineExplorer KG (N=5000)

Shapes file: `sparql/cineexplorer_shapes.ttl` — 5 NodeShapes (CreativeWork, Person, Episode, Participation, Genre).

## Run 1 — no inference

Command:
```bash
pyshacl -s sparql/cineexplorer_shapes.ttl \
        -d output/cineexplorer_kg.ttl \
        -f human -o sparql/results/shacl_run1_no_inference.txt
```

Wall time: ~3m. **Conforms: False — 105,964 violations.**

All violations from `ParticipationShape`'s `sh:class ce:CreativeWork` constraint on `ce:participatesIn`.

**Why:** Without inference, SHACL operates on the asserted graph. The KG types every title as `ce:Film`/`ce:Series`/`ce:Episode` directly — no entity has `rdf:type ce:CreativeWork` asserted. So the `sh:class ce:CreativeWork` constraint sees zero CreativeWork instances and reports the value of every `participatesIn` edge as a violation (105,964 = exact Participation count).

This is the classic OWA-vs-CWA contrast in action. OWL's class hierarchy says "every Film *is* a CreativeWork," but SHACL without inference doesn't apply that subclass reasoning — it asks "is the rdf:type triple literally present?"

## Run 2 — RDFS inference on (ontology + data)

Command:
```bash
pyshacl -s sparql/cineexplorer_shapes.ttl \
        -e ontology/cineexplorer_ontology.ttl \
        -i rdfs \
        -d output/cineexplorer_kg.ttl \
        -f human -o sparql/results/shacl_run2_rdfs_inference.txt
```

Wall time: ~6m. **Conforms: False — 75 violations across 25 distinct focus nodes.**

All 75 violations are on `CreativeWorkShape`:

| Constraint | Violations |
|---|---|
| `ce:workTitle` minCount 1 | 25 |
| `ce:averageRating` minCount 1 | 25 |
| `ce:numVotes` minCount 1 | 25 |

The 25 focus nodes are titles that get inferred to `ce:CreativeWork` (via `rdfs:range` on `ce:knownFor`, `ce:participatesIn`, etc.) but have no `workTitle`, `averageRating`, or `numVotes` triples — i.e. the title row itself was not produced by any `rr:class` triple-map.

**Root cause:** The mapping covers `TITLE_TYPE_ID IN ('movie', 'tvSeries', 'tvMiniSeries', 'tvPilot', 'tvEpisode')`. The N=5000 slice also contains 25 titles of unmapped types:

| TITLE_TYPE_ID | count |
|---|---|
| video | 9 |
| short | 5 |
| tvMovie | 5 |
| tvSpecial | 3 |
| videoGame | 3 |

These titles have participations (so `participatesIn` triples reference them) and are sometimes a person's known-for title (so `knownFor` triples reference them). Under RDFS inference those object positions get inferred-typed as `CreativeWork` even though no triple-map ever produced their core attributes.

## Interpretation

Run 1 vs Run 2 is the textbook OWA/CWA story we want for the SHACL demonstrator: the same shapes graph yields very different results depending on whether the validator is told about the ontology. With RDFS inference, SHACL surfaces a real data-quality issue (25 phantom CreativeWorks) that would otherwise be invisible.

This is exactly the kind of structural integrity check OWL alone cannot give us: OWL would simply allow the inferred CreativeWork to "lack a recorded title" under the Open World Assumption, no contradiction. SHACL with RDFS inference treats it as a violation under the Closed World Assumption.

## Possible follow-up fixes (not applied — kept as demo finding)

1. Extend the mapping to cover unmapped types (e.g., `short`, `tvMovie`, `tvSpecial`, `video` → `ce:Film`; `videoGame` → either drop or add a new subclass). Would eliminate the 25 violations.
2. Filter the unmapped types out at ETL time in `database/imdb-schema.sql` (the canonical-population phase). Cleaner KG, but loses participations referencing those titles.
3. Leave as-is and document — the demonstrator value of "SHACL caught a mapping gap" is itself worth keeping in the report.

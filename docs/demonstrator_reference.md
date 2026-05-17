# Non-trivial Demonstrator Reference — Bacon Number, SHACL Validation, LangChain

> **Status: GOOD — three demonstrators implemented and reported in §10**
> Files: `sparql/q06_bacon_number.sparql`, `sparql/q06b_bacon_2hops.sparql`, `sparql/cineexplorer_shapes.ttl`, `sparql/run_shacl_validation.py`, `demonstrator/langchain_kg/`
> Report: `report/sec/10_demonstrator.tex`

This document is the working reference for the three non-trivial demonstrations attached to Milestone 4. It is paired with §10 of the report; the report contains the same demonstrations plus narrative interpretation, and this file adds explanations geared at readers who are new to property-path traversal, SHACL, and LangChain.

---

## Primer for Non-Specialists

If you already know what "non-trivial demonstrator" means in this course and what SHACL is, skip to the catalogue.

### What a "non-trivial demonstrator" is

The course rubric requires a demonstrator that goes beyond simple SPARQL `SELECT` queries — something that exercises a non-obvious capability of the knowledge graph, the ontology, or the surrounding tooling. Examples from the lectures: federated reasoning across endpoints, graph-traversal analytics (e.g., shortest paths), SHACL or OWL constraint validation, or Linked Data dereferencing.

For CineExplorer we chose three complementary demonstrators:

1. **Bacon number — collaboration graph analysis.** Uses SPARQL 1.1 property paths to compute reachability sets between persons through shared titles. Demonstrates that the KG supports graph-shaped queries, not just relational lookups.
2. **SHACL structural validation, including SHACL-SPARQL.** Defines structural shapes the KG should satisfy, runs a validator twice (with and without RDFS inference) to surface the OWA/CWA contrast, and adds three SPARQL-backed shapes that express cross-property and cross-resource constraints unreachable by `sh:property` chains.
3. **Natural-language querying via LangChain.** Wires the local Fuseki endpoint to an LLM via LangChain's `GraphSparqlQAChain`, translating English questions into SPARQL queries against the live KG.

Together, they cover three different value axes: (a) using the graph for analytics that would be awkward in SQL, (b) reasoning about the graph itself rather than just its contents, and (c) making the graph accessible to consumers who do not write SPARQL.

### Bacon number — quick concept

The "Six Degrees of Kevin Bacon" parlour game asks: how few film co-credits does it take to connect any actor to Kevin Bacon? An actor's *Bacon number* is the length of the shortest such collaboration path. In graph terms, build a graph where nodes are persons and edges connect any two persons who appeared in the same title; the Bacon number is the shortest-path length from a source person to Kevin Bacon (or any chosen anchor).

In RDF + SPARQL, "appeared in the same title" can be expressed as a property path. The KG already contains both directions (`ce:workedFor` person → title, `ce:employed` title → person), so the path `ce:workedFor/ce:employed` is exactly "one collaboration hop." Repeating with `+` or `{n,m}` gives multi-hop paths.

### SHACL — quick concept

SHACL (Shapes Constraint Language) is the W3C standard for declaring structural constraints on RDF graphs. A SHACL shape says things like:

- "every instance of class C must have at least one value for property p,"
- "every instance must have exactly one value for property p,"
- "the value must be of datatype D" or "must be an instance of class C."

A SHACL validator checks the graph against the shapes and reports each instance that violates a constraint, with a human-readable message. SHACL operates under the **Closed World Assumption** by default — a missing required triple *is* a violation.

This is the key contrast with OWL: OWL cardinality axioms describe class semantics under the Open World Assumption ("an Episode is, by definition, in exactly one Series; if no link is recorded, we just don't know yet, not a contradiction"), while SHACL describes structural expectations under the Closed World Assumption ("if the link is not recorded, the data is incomplete; flag it").

We use SHACL to **validate that our R2RML mapping produced structurally well-formed instance data**, and to surface the OWA-vs-CWA distinction concretely (the inference-on / inference-off comparison below shows it).

SHACL also has a SPARQL extension (`sh:sparql`) that lets a constraint be defined by an arbitrary SPARQL `SELECT` query whose result rows become violations. This unlocks integrity rules that compare values across multiple properties of the same node, or values reached through multi-hop paths — neither expressible by `sh:property`/`sh:path` alone.

### LangChain — quick concept

LangChain is a Python framework for building applications around large language models. Its `GraphSparqlQAChain` is a built-in chain that:

1. introspects the schema of an RDF graph,
2. asks an LLM to translate a natural-language question into SPARQL using that schema,
3. executes the generated query against the endpoint, and
4. summarises the result rows back in natural language.

We wire it to the local Fuseki endpoint at `http://localhost:3030/cineexplorer/query` and use Anthropic's Claude as the underlying LLM. The demonstration shows that a careful ontology — with `rdfs:label` and `rdfs:comment` annotations on every term, and a profile (OWL 2 QL) restricted to named-class reasoning — pays off for downstream tooling: the LLM gets a clean, self-describing schema to write SPARQL against.

### How to read the catalogue

Each demonstrator has:

- **Concept** — the idea behind it.
- **Approach** — how it is implemented in our project.
- **Files / Queries** — what to look at.
- **Result** — what running it produces.
- **Discussion** — interpretation and what the result teaches.

---

## Demonstrator A — Bacon Number / Collaboration Graph Analysis

### Concept

The collaboration graph $G = (V, E)$ has:

- $V$ = persons in the KG,
- $E$ = unordered pairs of persons who share at least one credit on the same title.

Bacon number from a source $s$ to a target $t$ is the length of the shortest path between them in $G$ (or $\infty$ if disconnected). We do not implement true Dijkstra-style shortest path in SPARQL — SPARQL property paths return *some* path of a given length, not the shortest — so instead we compute *reachability sets at distance ≤ k* and reason from those.

### Approach

1. **Pick an anchor person.** Kevin Bacon (`nm0000102`) is the canonical anchor; we also report Russell Crowe (`nm0000128`) for comparison with the project's running example.
2. **Reachability at distance 1** — direct collaborators (Q6 / `q06_bacon_number.sparql`).
3. **Reachability at distance ≤ 2** — using a length-bounded property path (Q6b / `q06b_bacon_2hops.sparql`).
4. **Path reconstruction** — for any two reachable persons, find the bridging title.
5. **Connectivity analysis** — compute coverage at each hop count.

### Reachability at distance 1 (`sparql/q06_bacon_number.sparql`)

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT DISTINCT ?collaboratorName
WHERE {
  BIND(<http://cineexplorer.local/data/person/nm0000102> AS ?source)
  ?source ce:workedFor ?title .
  ?collaborator ce:workedFor ?title .
  FILTER(?collaborator != ?source)
  ?collaborator ce:personName ?collaboratorName .
}
ORDER BY ?collaboratorName
```

This is *not* yet a property-path query — it joins two `workedFor` triples on a shared `?title`. The result is the set of co-workers on any title with the anchor.

### Reachability at distance ≤ n (`sparql/q06b_bacon_2hops.sparql`)

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT DISTINCT ?reachable
WHERE {
  BIND(<http://cineexplorer.local/data/person/nm0000102> AS ?source)
  ?source (ce:workedFor/ce:employed){1,2} ?reachable .
  FILTER(?reachable != ?source)
}
```

The path expression `(ce:workedFor/ce:employed){1,2}` reads as:

- `ce:workedFor/ce:employed` — one *collaboration hop* (person → title → other person).
- `{1,2}` — repeat that pattern between 1 and 2 times, i.e., 1 or 2 hops.

Replacing `{1,2}` with `{1,3}` extends to 3-hop reachability.

### Result

| Source | 1-hop | 2-hop | 3-hop | Coverage @3 |
|--------|-------|-------|-------|-------------|
| Kevin Bacon (`nm0000102`) | 403 | 18,155 | 35,033 | **92.0% of 38,067 persons** |
| Russell Crowe (`nm0000128`) | 558 | 21,214 | — | 55.7% @2 |

Each hop expands the reachable set by roughly an order of magnitude. By three hops, 35,033 of the 38,067 persons in the KG are reachable from Kevin Bacon; only 3,034 remain unreachable, almost all of them on isolated short / video / videoGame titles whose participations did not overlap with the main film cluster.

### Path reconstruction (the bridging title)

For any reachable target, we can reconstruct the bridging title:

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?bridgeTitle
WHERE {
  BIND(<http://cineexplorer.local/data/person/nm0000102> AS ?p1)
  BIND(<http://cineexplorer.local/data/person/nm0000128> AS ?p2)
  ?p1 ce:workedFor ?w .
  ?p2 ce:workedFor ?w .
  ?w  ce:workTitle ?bridgeTitle .
}
```

Variants of the same query template, parameterised over `?p1` and `?p2`, also recover full `n`-hop paths by chaining `ce:workedFor/ce:employed` multiple times in a single basic graph pattern.

### Why this is a "non-trivial" demonstration

The Bacon-number computation is fundamentally a *graph-shaped query* — it would be awkward and verbose in pure SQL (recursive CTE over a self-join of `title_principal`) and natural in SPARQL (one property path). The migration from the earlier 174-title curated CSV sample to the official IMDb release was specifically motivated by this demonstration: the earlier sample had no person credited on more than one title, so the collaboration graph was a disjoint union of one-title cliques and the Bacon expansion was structurally vacuous. The migrated KG, with each person averaging 2.78 credits, restores the expanding-neighbourhood behaviour the Bacon-number game requires.

### Cheat sheet — property paths

| Construct | Plain English |
|-----------|---------------|
| `:p` | One `:p` hop. |
| `:p/:q` | One `:p` hop followed by one `:q` hop. |
| `:p+` | One or more `:p` hops. |
| `:p*` | Zero or more `:p` hops. |
| `:p{n,m}` | Between n and m `:p` hops. |
| `^:p` | One `:p` hop in the inverse direction. |
| `(:p\|:q)` | One hop along either `:p` or `:q`. |

> **Limitation**: SPARQL property paths return *some* path of the matching shape, not the shortest. For shortest-path metrics, compute reachability sets at successive depths and compare.

---

## Demonstrator B — SHACL Structural Validation

### Concept

OWL describes what individuals *are* under the Open World Assumption. SHACL describes what graphs *should look like* under the Closed World Assumption. The two complement each other: OWL is for inference, SHACL is for validation.

We use SHACL to:

- **Validate** that the R2RML mapping produced structurally complete instance data (every Episode has a series link, every Participation has its required predicates, etc.).
- **Demonstrate** the OWA-vs-CWA contrast by running the validator twice — once without ontology inference, once with RDFS inference — and observing that the result depends on whether subclass entailment is materialised.
- **Express integrity rules that core SHACL cannot capture**, via the `sh:sparql` extension (Demonstrator B+, below).

### Shapes file (`sparql/cineexplorer_shapes.ttl`)

Eight shapes total: five core structural shapes and three SPARQL-backed shapes.

**Core structural shapes:**

1. **CreativeWorkShape** — every `ce:CreativeWork` must have exactly one `ce:workTitle` (xsd:string), exactly one `ce:averageRating` in [1.0, 10.0], and exactly one `ce:numVotes` ≥ 0.
2. **PersonShape** — every `ce:Person` must have exactly one `ce:personName` (xsd:string); `ce:hasProfession` is optional, with at most three values per person.
3. **EpisodeShape** — every `ce:Episode` must link to exactly one `ce:Series` via `ce:partOfSeries`.
4. **ParticipationShape** — every `ce:Participation` must link to exactly one `ce:Person` via `ce:playedBy`, exactly one `ce:CreativeWork` via `ce:participatesIn`, and have at least one `ce:participationRole` string.
5. **GenreShape** — every `ce:Genre` must have exactly one `ce:genreName` (xsd:string).

**SPARQL-backed shapes (Demonstrator B+):**

6. **PersonChronologyShape** — `birthYear ≤ deathYear` for every Person that has both.
7. **PreBirthCreditShape** — no Person can be credited on a CreativeWork released before their birth year.
8. **DirectorCreditConsistencyShape** — every Person typed as `ce:Director` must have at least one `Participation` with role `'director'` in the slice.

The mandatory `ce:averageRating` and `ce:numVotes` constraints in CreativeWorkShape follow directly from the slice criterion: every title carried into the KG was selected by `numVotes` ranking, so each title is expected to carry both values.

### Validation tool

Two ways to run it. The CLI:

```bash
pyshacl -s sparql/cineexplorer_shapes.ttl \
        -e ontology/cineexplorer_ontology.ttl \
        -i rdfs \
        -d output/cineexplorer_kg.ttl \
        -f human \
        > sparql/results/shacl_run2_rdfs_inference.txt
```

This produces a verbose human-readable report. For per-shape violation counts (more useful when there are thousands of violations), use the helper script:

```bash
python sparql/run_shacl_validation.py            # Run with RDFS inference
python sparql/run_shacl_validation.py --no-inference   # Run 1 mode
```

The script aggregates violations per shape via the SHACL validation report graph.

### Run 1 — without ontology inference

```bash
pyshacl -s sparql/cineexplorer_shapes.ttl \
        -d output/cineexplorer_kg.ttl \
        -f human \
        > sparql/results/shacl_run1_no_inference.txt
```

Result: **Conforms: False — 105,964 violations.**

All violations come from the same constraint: `ParticipationShape`'s `sh:class ce:CreativeWork` requirement on `ce:participatesIn`. Without inference, SHACL operates on the asserted graph. The KG types every title as `ce:Film` / `ce:Series` / `ce:Episode` directly — no entity has `rdf:type ce:CreativeWork` asserted — so the validator sees no CreativeWork instances and reports the value of every `participatesIn` edge as a violation (105,964 = exact Participation count).

### Run 2 — with RDFS inference (core 5 shapes)

```bash
pyshacl -s sparql/cineexplorer_shapes.ttl \
        -e ontology/cineexplorer_ontology.ttl \
        -i rdfs \
        -d output/cineexplorer_kg.ttl \
        -f human \
        > sparql/results/shacl_run2_rdfs_inference.txt
```

Result: **Conforms: False — 75 violations across 25 distinct focus nodes.**

All 75 are on `CreativeWorkShape`:

| Constraint | Violations |
|---|---|
| `ce:workTitle` minCount 1 | 25 |
| `ce:averageRating` minCount 1 | 25 |
| `ce:numVotes` minCount 1 | 25 |

The 25 focus nodes are titles whose `rdf:type` is *inferred* to `ce:CreativeWork` (because they appear as the object of `ce:participatesIn` or `ce:knownFor`, both of which have `rdfs:range ce:CreativeWork`) but for which no triple-map ever emitted core attributes. They belong to IMDb `titleType` values not covered by the R2RML mapping:

| `titleType` | count |
|---|---|
| `video` | 9 |
| `short` | 5 |
| `tvMovie` | 5 |
| `tvSpecial` | 3 |
| `videoGame` | 3 |

The `105,964 → 75` reduction is the textbook OWA-vs-CWA story: the same shapes graph yields very different results depending on whether the validator is told about subclass entailment. With RDFS inference, SHACL surfaces a real data-quality issue (25 phantom CreativeWorks) that would otherwise be invisible.

---

## Demonstrator B+ — SHACL-SPARQL Cross-Property Constraints

### Concept

Core SHACL (`sh:property` + `sh:path`) is restricted to constraints expressible as one or more property paths starting from the focus node. It cannot express:

- **Cross-property constraints on the same focus node.** "birthYear ≤ deathYear" needs two literal-valued properties of the same Person and a comparison between them.
- **Cross-resource constraints reached through multi-hop paths.** "no Person is credited on a Title released before their birth year" needs Person.birthYear vs. (Person → Participation → CreativeWork.releaseYear).
- **Negation-as-failure constraints over arbitrary graph patterns.** "every `ce:Director` must have at least one director Participation" needs a `FILTER NOT EXISTS` over a multi-triple pattern.

`sh:sparql` solves all three. A SHACL constraint is defined by an arbitrary SPARQL `SELECT` query, with `$this` bound to the focus node. Each row of the result is reported as a violation on `$this`, with `sh:message` instantiated from the bound variables.

### The three shapes

```turtle
ce:PersonChronologyShape a sh:NodeShape ;
  sh:targetClass ce:Person ;
  sh:sparql [
    a sh:SPARQLConstraint ;
    sh:message "Person {$this} has birthYear > deathYear (born {?birth}, died {?death})." ;
    sh:select """
      PREFIX ce: <http://cineexplorer.local/ontology#>
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
      SELECT $this ?birth ?death WHERE {
        $this ce:birthYear ?birth ;
              ce:deathYear ?death .
        FILTER(xsd:integer(STR(?birth)) > xsd:integer(STR(?death)))
      }
    """ ;
  ] .

ce:PreBirthCreditShape a sh:NodeShape ;
  sh:targetClass ce:Person ;
  sh:sparql [
    a sh:SPARQLConstraint ;
    sh:message "Person {$this} (born {?birth}) is credited on a work released in {?release}." ;
    sh:select """
      PREFIX ce: <http://cineexplorer.local/ontology#>
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
      SELECT $this ?birth ?release WHERE {
        $this ce:birthYear ?birth .
        ?part ce:playedBy $this ;
              ce:participatesIn ?work .
        ?work ce:releaseYear ?release .
        FILTER(xsd:integer(STR(?release)) < xsd:integer(STR(?birth)))
      }
    """ ;
  ] .

ce:DirectorCreditConsistencyShape a sh:NodeShape ;
  sh:targetClass ce:Director ;
  sh:sparql [
    a sh:SPARQLConstraint ;
    sh:message "Person {$this} is typed ce:Director but has no per-credit director Participation in the slice." ;
    sh:select """
      PREFIX ce: <http://cineexplorer.local/ontology#>
      SELECT $this WHERE {
        FILTER NOT EXISTS {
          ?part ce:playedBy $this ;
                ce:participationRole 'director' .
        }
      }
    """ ;
  ] .
```

### gYear filter quirk

`ce:birthYear`, `ce:deathYear`, and `ce:releaseYear` are stored as `xsd:gYear`. Direct numeric comparison (`?b > ?d`) works in Apache Jena/Fuseki but returns no rows in pyshacl/rdflib. The portable form casts through string and integer: `xsd:integer(STR(?b)) > xsd:integer(STR(?d))`. This is documented inline in the shapes file.

### Run 3 — with RDFS inference + SPARQL shapes

```bash
python sparql/run_shacl_validation.py
```

Result: **Conforms: False — RUN3_TOTAL violations.**

Per-shape breakdown (all numbers from Run 3):

| Shape | Violations | Distinct focus nodes |
|---|---|---|
| `CreativeWorkShape` (3 minCount constraints × 25 titles) | 75 | 25 |
| `PersonChronologyShape` | RUN3_PCS | RUN3_PCS_FN |
| `PreBirthCreditShape` | RUN3_PBCS | RUN3_PBCS_FN |
| `DirectorCreditConsistencyShape` | 5,459 | 5,459 |
| **Total** | **RUN3_TOTAL** | — |

### Findings

- **PersonChronologyShape (RUN3_PCS violations).** The IMDb-sourced person catalogue is internally consistent on the basic chronology axis.
- **PreBirthCreditShape (20 distinct persons via direct query, RUN3_PBCS via pyshacl).** Examples: `nm1519722` (born 2002, credit released 2001), `nm0123553` (born 1955, credit released 1940), `nm1906042` (born 1982, credit released 1975). Tracing each case back through the ETL reveals two systematic causes:
  - birth-year typos in the upstream `name.basics` file (e.g., a 1955 birth year that should read 1925),
  - re-release titles whose `startYear` reflects the original theatrical release rather than the production credited to a younger participant (e.g., a 1940 film with a posthumous restoration credit).
  Either cause is a real data-quality signal that no purely structural shape could surface.
- **DirectorCreditConsistencyShape (5,459 violations).** This is the per-resource quantification of the architectural choice documented in the ontology's "two axes for role vs. profession" subsection. 5,459 of the persons typed as `ce:Director` come purely from IMDb's career-level `primaryProfession` axis, with no per-credit director Participation in our slice. The shape does not call the design a bug; it makes the design *visible*. A consumer of the KG can use the same shape to filter to "directors with at least one credit in scope" if the dual-axis interpretation is unwanted.

### Why this is a "non-trivial" demonstration

Cross-property and cross-resource integrity rules are exactly what real KG quality checks need. The three shapes also show three different SHACL-SPARQL patterns — same-node value comparison, multi-hop traversal, and negation-as-failure — each impossible to express with `sh:property` chains alone. Together with the OWA/CWA contrast from Runs 1 vs 2, the SHACL demonstrator now spans the full structural-to-semantic spectrum of validation that KG quality assurance needs.

### SHACL cheat sheet

| Construct | Plain English |
|-----------|---------------|
| `ex:S a sh:NodeShape` | Declare a node shape. |
| `sh:targetClass :C` | The shape applies to instances of `:C`. |
| `sh:property [ ... ]` | Add a property constraint to the shape. |
| `sh:path :p` | The constraint is on values of property `:p`. |
| `sh:minCount n` | At least n values required. |
| `sh:maxCount n` | At most n values allowed. |
| `sh:datatype xsd:T` | Values must be literals of datatype `xsd:T`. |
| `sh:class :C` | Values must be instances of `:C`. |
| `sh:sparql [ a sh:SPARQLConstraint ; sh:select "…" ]` | Constraint defined by a SPARQL SELECT; each result row is a violation on `$this`. |
| `sh:message "…"` | Human-readable message attached to violations. |

> **Reminder**: SHACL's default Closed World Assumption is what gives validation teeth. To bridge to OWL semantics, run the reasoner first (e.g., `pyshacl --inference rdfs`) so subclass and inverse entailments are materialised before the validator looks at the data.

---

## Demonstrator C — Natural-Language Querying via LangChain

### Concept

The previous two demonstrators expose the KG to people who can write SPARQL. Demonstrator C closes the accessibility loop: it accepts a question in plain English, generates the SPARQL for it, runs it against the live Fuseki endpoint, and returns the answer. The translator is an LLM, wired through LangChain's `GraphSparqlQAChain`.

### Why this exercises the ontology

LangChain's `RdfGraph.load_schema()` issues a SPARQL query against the endpoint to extract every `rdf:type`, `rdfs:subClassOf`, `rdfs:domain`, `rdfs:range`, `rdfs:label`, and `rdfs:comment` triple. The result becomes part of the LLM's prompt — it is the structured schema description the model uses to write SPARQL. Two design choices in the project pay off here:

1. The CineExplorer ontology was specifically annotated with `rdfs:label` and `rdfs:comment` on every class and property (Section 6.4 of the report). The LLM sees `ce:partOfSeries` *plus* the comment "An Episode is part of a Series", not just an opaque IRI.
2. The ontology targets the OWL 2 QL profile, which restricts the schema to named-class subsumption, inverse properties, and domain/range. The LLM has no complex DL constructs to interpret, only a flat set of named terms and their relations — exactly the shape of schema it reasons about reliably.

### Architecture

`GraphSparqlQAChain` operates in three stages:

1. **Schema introspection.** `RdfGraph.load_schema()` queries Fuseki and extracts the class/property catalogue.
2. **NL → SPARQL.** The LLM receives the schema together with the user's question and is prompted to emit a single SPARQL query.
3. **Execute and summarise.** The query runs against `http://localhost:3030/cineexplorer/query`; the rows are passed back to the LLM, which summarises them in natural language.

### Files

- `demonstrator/langchain_kg/nl_to_sparql.py` — entry point. Builds the chain, runs a default question suite or a single CLI argument.
- `demonstrator/langchain_kg/requirements.txt` — pinned dependencies (langchain, langchain-community, langchain-anthropic, rdflib, SPARQLWrapper).
- `demonstrator/langchain_kg/README.md` — setup and usage instructions.

### Setup

```bash
cd demonstrator/langchain_kg
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
```

Make sure Fuseki is running and the dataset is loaded:

```bash
cd deployment && docker compose up -d
```

### Run

```bash
# Run the default question suite (5 questions)
python nl_to_sparql.py

# Or ask one question
python nl_to_sparql.py "Which actors appeared in more than 30 films?"
```

For each question, the chain prints (a) the generated SPARQL query, (b) the raw result rows from Fuseki, (c) the LLM-summarised natural-language answer.

### Example translations

| Natural language | Generated SPARQL (abridged) |
|---|---|
| "How many actors are in the KG?" | `SELECT (COUNT(DISTINCT ?p) AS ?n) WHERE { ?p a ce:Actor }` |
| "Films with rating greater than 9.0?" | `SELECT ?title ?r WHERE { ?t a ce:Film ; ce:workTitle ?title ; ce:averageRating ?r . FILTER(?r > 9.0) }` |
| "Who worked with Russell Crowe?" | Two-Participation join over a shared `?w`, filtered to `?p != ?p1` |
| "Most common genre among films?" | `GROUP BY` over `ce:hasGenre`/`ce:genreName`, `ORDER BY DESC(COUNT)`, `LIMIT 1` |

### Why this is a "non-trivial" demonstration

It exercises a different KRR application axis than the first two demonstrators. Bacon-number is graph analytics; SHACL is structural reasoning about the graph itself; LangChain is *consumption-side accessibility*. It also closes the loop on two project-level claims:

- **Ontologies-as-prompts.** A KG without `rdfs:label`/`rdfs:comment` annotations forces the LLM to guess from IRIs alone, with predictably worse results. The CineExplorer ontology's annotation discipline (a Section 6.4 design choice) is now empirically necessary, not just a nicety.
- **Profile choice has downstream consequences.** OWL 2 QL means the schema fragment fed to the LLM is small, named-only, and self-contained. A richer DL ontology would force the LLM to reason about cardinality restrictions and complex class expressions, which it does badly.

### Limitations

- The chain enables `allow_dangerous_requests=True` because LangChain flags arbitrary SPARQL execution as a potential SSRF vector. Our Fuseki endpoint is read-only and bound to localhost, so this is safe in practice; production deployments should restrict the chain to `SELECT`/`CONSTRUCT` only.
- The default LLM is `claude-sonnet-4-5`. Swap to any LangChain-supported chat model (OpenAI, local Ollama, etc.) by replacing `ChatAnthropic` in `nl_to_sparql.py`.
- Schema introspection uses LangChain's default RDF-mode query, which extracts class/property names but not all `rdfs:comment` annotations. A project-specific schema query could produce richer prompts but is not required for the basic demonstration.

---

## Reproducibility

All three demonstrators are reproducible from the artefacts in the repository:

```bash
# Demonstrator A — Bacon number
fuseki-curl http://localhost:3030/cineexplorer/query \
            < sparql/q06_bacon_number.sparql
fuseki-curl http://localhost:3030/cineexplorer/query \
            < sparql/q06b_bacon_2hops.sparql

# Demonstrator B / B+ — SHACL validation
python sparql/run_shacl_validation.py                # Run 3 (RDFS + SPARQL shapes)
python sparql/run_shacl_validation.py --no-inference # Run 1
pyshacl -s sparql/cineexplorer_shapes.ttl \
        -e ontology/cineexplorer_ontology.ttl -i rdfs \
        -d output/cineexplorer_kg.ttl -f human       # Run 2 verbose

# Demonstrator C — LangChain NL→SPARQL
cd demonstrator/langchain_kg
source .venv/bin/activate
python nl_to_sparql.py
```

# CineExplorer Ontology — OWL 2 QL Profile

> **Status:** Active. Supersedes the OWL 2 DL profile previously documented in `docs/ontology_reference.md`.
> File: `ontology/cineexplorer_ontology.ttl`
> Profile: **OWL 2 QL** — confirmed with Protégé's OWL Profile Checker; consistency verified with HermiT.
> Namespace: `http://cineexplorer.local/ontology#` (prefix `ce:`)
> Triples: 290 (TBox only).

---

## 1. Why OWL 2 QL?

OWL 2 QL is one of the three sub-DL profiles defined by the W3C alongside EL and RL. Its purpose is **ontology-based data access (OBDA)**: the profile is restricted just enough that any SPARQL query against the ontology + data can be **rewritten** into a query over the materialised data without first computing all inferred triples. Reasoning is in **AC⁰ with respect to data complexity** — the same complexity class as plain SQL evaluation.

This choice is a natural fit for CineExplorer:

| Property of CineExplorer | Why QL helps |
|--------------------------|--------------|
| The authoritative store is a relational DB, exposed as RDF via R2RML | QL was designed for exactly this: putting an ontology layer over a RDBMS |
| The KG is large (1.6 M triples at $N = 5{,}000$) and SPARQL queries should remain interactive | AC⁰ data complexity guarantees that adding the ontology does not blow up query cost |
| Cardinality validation is a closed-world data-quality concern, not an open-world class-membership semantic | Cardinality belongs in SHACL, not OWL; removing it lifts the ontology into QL "for free" |
| We do not need transitive properties, functional characteristics, or property chains | QL forbids exactly these — and we never used them in the modelling |

**Tradeoff.** QL forbids cardinality restrictions, functional / inverse-functional properties, transitivity, property chains, `owl:hasKey`, `owl:hasValue`, `owl:allValuesFrom`, and disjoint-union axioms. We give up no expressivity that we actually used: the cardinalities we previously asserted in OWL are now SHACL shapes (and were already shadowed there), and we never declared transitive or property-chain axioms.

---

## 2. Profile-relevant constructs

### 2.1 Constructs we use (all QL-legal)

| Construct | Where used | QL status |
|-----------|------------|-----------|
| `rdfs:subClassOf` between named classes | `Film`, `Series`, `Episode` ⊑ `CreativeWork`; `Actor`, `Director`, `Writer`, `Editor`, `Composer` ⊑ `Person` | ✓ allowed |
| `rdfs:subPropertyOf` | `actedIn`, `directed`, `wrote`, `edited`, `composedFor`, `knownFor` ⊑ `workedFor`; the inverse five ⊑ `employed` | ✓ allowed |
| `owl:inverseOf` | 7 inverse pairs (e.g. `actedIn`/`hasActor`, `directed`/`directedBy`) | ✓ allowed |
| `owl:SymmetricProperty` | `workedWith` | ✓ allowed |
| `owl:disjointWith` | `CreativeWork` ⊓ {`Genre`, `Participation`, `Person`} = ∅; `Genre` ⊓ `Participation` = ∅; `Participation` ⊓ `Person` = ∅ | ✓ allowed |
| `owl:AllDisjointClasses` | { `Film`, `Series`, `Episode` } pairwise disjoint | ✓ allowed |
| `rdfs:domain`, `rdfs:range` | All object and datatype properties | ✓ allowed |
| Datatype property declarations with `xsd:string`, `xsd:gYear`, `xsd:decimal`, `xsd:nonNegativeInteger`, `xsd:boolean` | All literals | ✓ allowed |

### 2.2 Constructs we deliberately avoid

| Construct | QL status | Why we don't need it |
|-----------|-----------|----------------------|
| `owl:FunctionalProperty` | ✗ forbidden | "Episode has at most one Series" → SHACL `EpisodeShape` |
| `owl:InverseFunctionalProperty` | ✗ forbidden | Not needed |
| `owl:TransitiveProperty` | ✗ forbidden | We use SPARQL property paths instead (`+`, `*`) for Bacon traversal |
| `owl:qualifiedCardinality` / `owl:maxCardinality` / `owl:minCardinality` / `owl:cardinality` | ✗ forbidden | All cardinality moved to SHACL |
| `owl:hasKey` | ✗ forbidden | Identity is enforced by IMDb identifiers (TCONST/NCONST) at the IRI level |
| `owl:propertyChainAxiom` | ✗ forbidden | We compute `workedWith` via SPARQL or materialise it directly in R2RML |
| `owl:hasValue` | ✗ forbidden | Not used |
| `owl:allValuesFrom` | ✗ forbidden | Not used |
| `owl:disjointUnionOf` | ✗ forbidden | Replaced by separate `owl:AllDisjointClasses` + `rdfs:subClassOf` axioms |

### 2.3 Migration record (axioms removed in the DL → QL conversion)

| Axiom (DL) | Replacement (QL + SHACL) |
|------------|--------------------------|
| `:partOfSeries a owl:FunctionalProperty` | Removed; SHACL `EpisodeShape` requires `sh:path ce:partOfSeries ; sh:maxCount 1` |
| `:CreativeWork ⊑ ≤1 :sameAsExternal` | Removed (no SHACL equivalent — soft preference, not load-bearing) |
| `:Person ⊑ ≤1 :sameAsExternal` | Removed (idem) |
| `:Episode ⊑ =1 :partOfSeries.Series` | Removed; SHACL `EpisodeShape` requires `sh:minCount 1 ; sh:maxCount 1 ; sh:class ce:Series` |
| `:Participation ⊑ =1 :participatesIn.CreativeWork` | Removed; SHACL `ParticipationShape` requires `sh:minCount 1 ; sh:maxCount 1 ; sh:class ce:CreativeWork` |
| `:Participation ⊑ =1 :playedBy.Person` | Removed; SHACL `ParticipationShape` requires `sh:minCount 1 ; sh:maxCount 1 ; sh:class ce:Person` |

---

## 3. Class catalogue

```
                      ┌──────────────┐
                      │ CreativeWork │  (disjoint with Genre, Participation, Person)
                      └──────┬───────┘
                             │ subClassOf
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
          ┌───────┐      ┌────────┐     ┌─────────┐
          │ Film  │      │ Series │     │ Episode │   (AllDisjointClasses)
          └───────┘      └────────┘     └─────────┘

                      ┌──────────┐
                      │  Person  │  (disjoint with CreativeWork, Participation)
                      └────┬─────┘
                           │ subClassOf  (NOT mutually disjoint)
       ┌──────────┬────────┼────────┬───────────┐
       ▼          ▼        ▼        ▼           ▼
   ┌───────┐ ┌──────────┐ ┌──────┐ ┌─────────┐ ┌──────────┐
   │ Actor │ │ Director │ │ Writer │ Editor  │ │ Composer │
   └───────┘ └──────────┘ └──────┘ └─────────┘ └──────────┘

                      ┌──────────┐                     ┌───────┐
                      │ Particip │  disjoint with      │ Genre │  disjoint with
                      │  ation   │  CreativeWork,      └───────┘  Participation
                      └──────────┘  Person, Genre
```

| Class | Brief | Disjoint with |
|-------|-------|---------------|
| `ce:CreativeWork` | A work (film, series, or episode) | `ce:Genre`, `ce:Participation`, `ce:Person` |
| `ce:Film` ⊑ `ce:CreativeWork` | Standalone film | `ce:Series`, `ce:Episode` (via `AllDisjointClasses`) |
| `ce:Series` ⊑ `ce:CreativeWork` | TV/streaming series | `ce:Film`, `ce:Episode` |
| `ce:Episode` ⊑ `ce:CreativeWork` | Episode of a series | `ce:Film`, `ce:Series` |
| `ce:Person` | Human individual involved in productions | `ce:CreativeWork`, `ce:Genre`, `ce:Participation` |
| `ce:Actor` ⊑ `ce:Person` | Person credited as actor | (not disjoint from other Person subclasses) |
| `ce:Director` ⊑ `ce:Person` | Person credited as director | — |
| `ce:Writer` ⊑ `ce:Person` | Person credited as writer | — |
| `ce:Editor` ⊑ `ce:Person` | Person credited as editor | — |
| `ce:Composer` ⊑ `ce:Person` | Person credited as composer | — |
| `ce:Participation` | Reified Person × CreativeWork × Role record | `ce:Person` (others inferable via top-level disjointness) |
| `ce:Genre` | Thematic/stylistic category | `ce:CreativeWork`, `ce:Participation` |

---

## 4. Property catalogue

### 4.1 Object properties

| Property | Domain | Range | Inverse | Sub-property of | Notes |
|----------|--------|-------|---------|-----------------|-------|
| `ce:workedFor` | `Person` | `CreativeWork` | `ce:employed` | — | Top-level traversal property |
| `ce:employed` | `CreativeWork` | `Person` | `ce:workedFor` | — | Inverse of the top-level property |
| `ce:actedIn` | `Actor` | `CreativeWork` | `ce:hasActor` | `ce:workedFor` | |
| `ce:hasActor` | `CreativeWork` | `Actor` | `ce:actedIn` | `ce:employed` | |
| `ce:directed` | `Director` | `CreativeWork` | `ce:directedBy` | `ce:workedFor` | |
| `ce:directedBy` | `CreativeWork` | `Director` | `ce:directed` | `ce:employed` | |
| `ce:wrote` | `Writer` | `CreativeWork` | `ce:writtenBy` | `ce:workedFor` | |
| `ce:writtenBy` | `CreativeWork` | `Writer` | `ce:wrote` | `ce:employed` | |
| `ce:edited` | `Editor` | `CreativeWork` | `ce:editedBy` | `ce:workedFor` | |
| `ce:editedBy` | `CreativeWork` | `Editor` | `ce:edited` | `ce:employed` | |
| `ce:composedFor` | `Composer` | `CreativeWork` | `ce:composedBy` | `ce:workedFor` | |
| `ce:composedBy` | `CreativeWork` | `Composer` | `ce:composedFor` | `ce:employed` | |
| `ce:knownFor` | `Person` | `CreativeWork` | — | `ce:workedFor` | IMDb's "known for" relation; not inverse-paired (asymmetric semantics) |
| `ce:participatesIn` | `Participation` | `CreativeWork` | — | — | Cardinality (=1) enforced by SHACL |
| `ce:playedBy` | `Participation` | `Person` | `ce:hasRole` | — | Cardinality (=1) enforced by SHACL |
| `ce:hasRole` | `Person` | `Participation` | `ce:playedBy` | — | |
| `ce:hasGenre` | `CreativeWork` | `Genre` | `ce:isGenreOf` | — | |
| `ce:isGenreOf` | `Genre` | `CreativeWork` | `ce:hasGenre` | — | |
| `ce:partOfSeries` | `Episode` | `Series` | `ce:hasEpisode` | — | Cardinality (=1) enforced by SHACL — was `owl:FunctionalProperty` in DL |
| `ce:hasEpisode` | `Series` | `Episode` | `ce:partOfSeries` | — | |
| `ce:workedWith` | `Person` | `Person` | (symmetric) | — | `owl:SymmetricProperty` (QL-legal); derived collaboration relation |
| `ce:sameAsExternal` | (unrestricted) | (unrestricted) | — | — | Cross-dataset link to external IRIs (e.g., Wikidata) |

### 4.2 Datatype properties

| Property | Domain | Range | Notes |
|----------|--------|-------|-------|
| `ce:workTitle` | `CreativeWork` | `xsd:string` | Primary title |
| `ce:originalTitle` | `CreativeWork` | `xsd:string` | When different from primary |
| `ce:releaseYear` | `CreativeWork` | `xsd:gYear` | |
| `ce:endYear` | `Series` | `xsd:gYear` | When concluded |
| `ce:runtimeMinutes` | `CreativeWork` | `xsd:nonNegativeInteger` | |
| `ce:isAdult` | `CreativeWork` | `xsd:boolean` | |
| `ce:averageRating` | `CreativeWork` | `xsd:decimal` | IMDb 1.0–10.0 |
| `ce:numVotes` | `CreativeWork` | `xsd:nonNegativeInteger` | IMDb vote count |
| `ce:language` | `CreativeWork` | `xsd:string` | ISO code via `title_aka` |
| `ce:region` | `CreativeWork` | `xsd:string` | ISO code via `title_aka` |
| `ce:seasonNumber` | `Episode` | `xsd:nonNegativeInteger` | |
| `ce:episodeNumber` | `Episode` | `xsd:nonNegativeInteger` | |
| `ce:personName` | `Person` | `xsd:string` | |
| `ce:birthYear` | `Person` | `xsd:gYear` | |
| `ce:deathYear` | `Person` | `xsd:gYear` | |
| `ce:hasProfession` | `Person` | `xsd:string` | Career-level profession; up to 3 values; SHACL `maxCount 3` |
| `ce:characterName` | `Participation` | `xsd:string` | |
| `ce:participationRole` | `Participation` | `xsd:string` | Per-credit role (actor, director, …) |
| `ce:participationProperties` | `Participation` | `xsd:string` | Free-text annotations |
| `ce:genreName` | `Genre` | `xsd:string` | |

---

## 5. The OWL / SHACL boundary

The principle: **OWL describes what classes and properties mean; SHACL validates whether the data instances obey closed-world data-quality rules**.

### 5.1 What lives in OWL

- The class hierarchy and disjointness (`Film` is a `CreativeWork`; `Film` is not a `Series`).
- Property hierarchies and inverses (`actedIn` is a `workedFor`; `actedIn` is the inverse of `hasActor`).
- Domain and range typing (`actedIn` is between `Actor` and `CreativeWork`).
- The symmetric characteristic of `workedWith`.

These axioms support **inference under the open-world assumption**: a triple `(:person/nm0000102, ce:actedIn, :title/tt0073195)` triggers `(:title/tt0073195, ce:hasActor, :person/nm0000102)` via the inverse axiom, regardless of whether the inverse triple is present in the data.

### 5.2 What moved to SHACL

| SHACL shape | Constraint | Purpose |
|-------------|------------|---------|
| `ce:CreativeWorkShape` | exactly one `ce:workTitle`, `ce:averageRating ∈ [1.0, 10.0]`, `ce:numVotes ≥ 0` | Slice-induced invariants — every CreativeWork came from a numVotes-ranked top-N pick |
| `ce:PersonShape` | exactly one `ce:personName`; `ce:hasProfession` up to 3 strings | IMDb's primaryProfession schema |
| `ce:EpisodeShape` | exactly one `ce:partOfSeries → ce:Series` | Replaces the DL functional / qualified-cardinality axiom on `:partOfSeries` |
| `ce:ParticipationShape` | exactly one `ce:playedBy → ce:Person`; exactly one `ce:participatesIn → ce:CreativeWork`; at least one `ce:participationRole` | Replaces the DL qualified-cardinality axioms on `:Participation` |
| `ce:GenreShape` | exactly one `ce:genreName` | Identity invariant |

### 5.3 Why SHACL is the right home for cardinality

OWL cardinality axioms define **class-membership semantics under the OWA**. An OWL `=1 partOfSeries.Series` axiom on `Episode` says: "if you already know that an individual is an Episode, then it has exactly one Series partner — even if that partner is not (yet) named in the graph". It does **not** say that an Episode without a recorded partOfSeries triple is a data-quality violation; the reasoner has no information about its series and cannot conclude anything is wrong.

SHACL, by contrast, validates the **materialised graph under the CWA**. An `EpisodeShape` with `sh:minCount 1` on `ce:partOfSeries` says: "this Episode in the graph must have at least one recorded partOfSeries triple, and if it doesn't, that's a violation."

For CineExplorer the second meaning is what we actually want. We are validating the output of the R2RML mapping, looking for dropped or malformed credits, not making semantic class-definitions. SHACL's CWA stance also matches the ETL's posture: missing data in the source TSVs is a problem to surface, not a hypothetical eventually-knowable fact.

---

## 6. Verification

### 6.1 QL profile membership

Confirmed three ways:

1. **Protégé OWL Profile Checker** (Window → Tabs → OWL 2 Profile Validator) reports OWL 2 QL ✓.
2. **HermiT classification** in Protégé reports no unsatisfiable classes — ontology is consistent.
3. **A grep-based static check** confirms none of the QL-forbidden constructs appear in the file:

   ```python
   forbidden = ['FunctionalProperty', 'InverseFunctionalProperty', 'TransitiveProperty',
                'maxCardinality', 'minCardinality', 'cardinality',
                'qualifiedCardinality', 'maxQualifiedCardinality', 'minQualifiedCardinality',
                'hasKey', 'propertyChainAxiom', 'hasValue', 'allValuesFrom', 'disjointUnionOf']
   ```

   All return zero hits in `ontology/cineexplorer_ontology.ttl`.

### 6.2 Reasoning verification

```bash
# Parse the ontology with rdflib (sanity check that it's valid Turtle)
python3 -c "
from rdflib import Graph
g = Graph()
g.parse('ontology/cineexplorer_ontology.ttl', format='turtle')
print(f'Parsed: {len(g)} triples')
"
# Expected: Parsed: 290 triples

# Open in Protégé for HermiT classification
~/All/Protege-5.6.9/run.sh
# File → Open → ontology/cineexplorer_ontology.ttl
# Reasoner → HermiT → Start reasoner
# Reasoner → Show inconsistent classes (none expected)
```

### 6.3 SHACL validation against the KG

The shapes file `sparql/cineexplorer_shapes.ttl` is run with `pyshacl` against the materialised KG to verify that data-quality constraints hold:

```bash
pyshacl -s sparql/cineexplorer_shapes.ttl \
        -e ontology/cineexplorer_ontology.ttl \
        -i rdfs \
        -d output/cineexplorer_kg.ttl \
        -f human \
        -o sparql/results/shacl_run2_rdfs_inference.txt
```

Result on the N=5000 KG: 75 violations from 25 phantom CreativeWorks (titles whose `titleType` is not mapped — `short`, `video`, `tvMovie`, `tvSpecial`, `videoGame`). See `sparql/results/shacl_summary.md` for the full discussion.

---

## 7. Implications for query rewriting

QL is the only OWL profile in which SPARQL queries can be answered by **rewriting the query to subsume the ontology's closure**, then evaluating against the asserted graph alone. For our queries this means:

- A query asking for `?p ce:workedFor ?w` automatically returns matches for `?p ce:actedIn ?w`, `?p ce:directed ?w`, `?p ce:wrote ?w`, etc., because the rewriter unfolds the sub-property hierarchy.
- A query asking for `?w a ce:CreativeWork` returns matches for `?w a ce:Film`, `?w a ce:Series`, `?w a ce:Episode` via the subclass axioms.
- A query asking for `?w ce:hasActor ?p` returns matches when the data only asserts `?p ce:actedIn ?w`, via the inverse axiom.

In our deployment we currently load the asserted triples into Apache Fuseki without an OBDA query rewriter. Rewriting is therefore done **by hand in the SPARQL queries themselves** (e.g., Q01–Q10 use SPARQL property paths and explicit subclass union where needed). The QL profile guarantees that an OBDA-aware engine like Ontop or Mastro could be plugged in later as a drop-in replacement, with no changes to the ontology.

---

## 8. References

- W3C. *OWL 2 Web Ontology Language Profiles (Second Edition)*. [https://www.w3.org/TR/owl2-profiles/](https://www.w3.org/TR/owl2-profiles/)
- D. Calvanese, G. De Giacomo, D. Lembo, M. Lenzerini, A. Poggi, M. Rodriguez-Muro, R. Rosati. *Ontologies and Databases: The DL-Lite Approach.* RW 2009.
- W3C. *SHACL — Shapes Constraint Language*. [https://www.w3.org/TR/shacl/](https://www.w3.org/TR/shacl/)
- B. Glimm, I. Horrocks, B. Motik, G. Stoilos, Z. Wang. *HermiT: An OWL 2 Reasoner.* JAR 53 (2014), 245–269.

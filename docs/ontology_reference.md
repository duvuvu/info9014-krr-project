# Ontology Reference — CineExplorer OWL 2 DL

> **Status: GOOD — all M2 fixes applied**
> File: `cineexplorer_ontology.ttl`
> Version: v6. Profile: OWL 2 DL (HermiT-verified in Protégé 5.6.9).
> Namespace: `http://cineexplorer.local/ontology#` (prefix `ce:`)

---

## Known Issues (tracked)

| ID | Severity | Issue | Status |
|----|----------|-------|--------|
| FIX-01 | HIGH | `example.org` namespace — replaced with `cineexplorer.local` | **Solved** |
| FIX-02 | HIGH | `personProperties` / `creativeWorkProperties` / `episodeProperties` packed multiple values into one literal — removed; replaced by `originalTitle`, `endYear` | **Solved** |
| FIX-04 | MEDIUM | `language` / `region` now store ISO codes (Option A — keep as literals, use `LANGUAGE_ID`/`REGION_ID`) | **Solved** |
| FIX-05 | MEDIUM | `sameAsExternal` declared but not populated — reframed as query-time Wikidata federation (M4) | **Approved / M4** |
| FIX-06 | MEDIUM | `minQualifiedCardinality "0"` blocks removed; §6.5 rewritten with 4 concrete paragraphs | **Solved** |
| FIX-07 | LOW | `played` duplicates `actedIn` (same domain/range/superproperty) — pending teammate verification | **Waitlist** |

---

## Primer for Non-Specialists

This section explains the concepts a reader needs to interpret the rest of the document. If you already know RDF/OWL, skip ahead.

### What an ontology is, in this project

The ontology is a formal vocabulary for the cinema domain. It declares which **classes** exist (e.g., `Film`, `Person`, `Genre`), which **properties** exist (e.g., `actedIn`, `hasGenre`), and **rules** about how those classes and properties relate (e.g., "every Episode belongs to exactly one Series", "Film and Series do not overlap"). It is *not* a data file — it does not contain the actual films and persons. The data lives in the knowledge graph (`output/cineexplorer_kg.ttl`), generated from MySQL via R2RML.

### RDF in 60 seconds

All data and ontology terms are expressed as **triples**: `(subject, predicate, object)`. Every subject and predicate, and most objects, are identified by **IRIs** (globally unique URLs). Some objects are **literals** — typed values such as strings, integers, or dates. Example triple:

```
<http://cineexplorer.local/data/person/nm0000128>  ce:personName  "Russell Crowe" .
```

Turtle syntax (used in the `.ttl` files) is just a compact way to write triples, with `@prefix` declarations to abbreviate IRIs.

### OWL in 60 seconds

OWL (Web Ontology Language) is a vocabulary built on top of RDF. It adds constructs for:

- declaring class hierarchies (`rdfs:subClassOf`),
- declaring property characteristics (`owl:FunctionalProperty`, `owl:SymmetricProperty`, `owl:inverseOf`),
- expressing logical conditions (disjointness, cardinality restrictions, equivalence).

OWL has several **profiles** (DL, EL, QL, RL, Full) that trade expressive power for computational tractability. We use **OWL 2 DL** — the standard "expressive but still decidable" profile. The next subsection explains what each profile is and why DL is the right fit for this project.

### OWL 2 Profiles — DL, EL, QL, RL, and Full

OWL 2 defines four standard profiles, plus the unprofiled "OWL 2 Full". Each profile is a *syntactic fragment* of OWL 2 — a restricted subset of allowed constructs — chosen so that reasoning has predictable complexity. Picking a profile is not an aesthetic choice; it determines which reasoners can be used and how queries scale.

#### The five fragments, ranked by reasoning cost

| Profile | Reasoning complexity | Designed for | Typical use |
|---------|---------------------|--------------|-------------|
| **OWL 2 EL** | Polynomial time (PTIME) | Very large class hierarchies | Biomedical ontologies — SNOMED CT, Gene Ontology |
| **OWL 2 QL** | AC⁰ (essentially SQL) | Query answering over relational data | Ontology-Based Data Access (OBDA), Mastro, Ontop |
| **OWL 2 RL** | Polynomial time (rule-based) | Rule-engine implementations | Datalog-extended databases, business rules |
| **OWL 2 DL** | Worst-case 2NEXPTIME, practical | General-purpose expressive ontologies | Most academic and Protégé-edited ontologies — **including ours** |
| OWL 2 Full | Undecidable | Maximum semantic permissiveness | Theoretical; no sound-and-complete reasoner exists |

The three sub-DL profiles (EL, QL, RL) are *pairwise incomparable*: each forbids constructs the others allow. They are not points on a single line of expressivity but three different "directions" of restriction, each tuned to a different implementation strategy.

#### What each profile allows and forbids (sketch)

**OWL 2 EL** — keeps reasoning polynomial even with hundreds of thousands of classes. Allows existential restrictions (`someValuesFrom`), intersection, simple role hierarchies, role chains, and basic disjointness. **Forbids**: universal restrictions (`allValuesFrom`), inverse properties, symmetric properties, functional properties (mostly), cardinality restrictions other than the trivial cases, negation, disjunction. Used by the medical informatics community where ontologies have ~400,000 classes and the cost of full DL reasoning would be prohibitive.

**OWL 2 QL** — designed so that every entailed query can be answered by *rewriting* the SPARQL query into SQL and running it against the original relational data, with no materialisation of inferred triples. Allows class/property hierarchies, mandatory participation, inverses, basic disjointness. **Forbids**: cardinality restrictions, functional properties, transitivity, and most complex class expressions. Used by OBDA tools (Ontop, Mastro) to put a semantic layer on top of an existing database.

**OWL 2 RL** — every axiom must correspond to a Datalog rule, so that reasoning can be implemented by forward-chaining in any standard rule engine. Allows almost everything but with positional restrictions: cardinality on the left of `subClassOf`, but not the right; functional/inverse-functional/transitive properties; disjointness. Used by triplestores that extend a RDBMS with rule-based inference, and by ontologies that need to interoperate with rule systems.

**OWL 2 DL** — the maximum expressivity that keeps reasoning decidable. Built on the description logic SROIQ. Allows: qualified cardinality (`exactly 1`, `at most 5`), full Boolean class expressions (intersection, union, complement), all property characteristics (inverse, symmetric, asymmetric, functional, inverse-functional, transitive, reflexive, irreflexive), disjointness, equivalence, role chains in restricted positions, `hasSelf`. Worst-case reasoning is in 2NEXPTIME, but modern reasoners (HermiT, Pellet, FaCT++) handle realistic ontologies in milliseconds to seconds — they exploit the fact that real ontologies almost never trigger the worst case.

**OWL 2 Full** — drops the syntactic restrictions of DL. Permits "punning" (treating a class as an instance of a metaclass), treating properties as classes, mixing the meta-level with the object-level. Reasoning becomes undecidable: no algorithm can be guaranteed to terminate with the correct answer for arbitrary OWL 2 Full ontologies. There is no complete reasoner. OWL 2 Full is mostly of theoretical interest.

#### Why this project is in OWL 2 DL (and not one of the lighter profiles)

CineExplorer uses three constructs that together push the ontology out of EL, QL, and RL:

1. **Qualified cardinality** — e.g., `Episode subClassOf [partOfSeries exactly 1 Series]`. EL allows only `someValuesFrom` (existential); QL forbids cardinality entirely; RL forbids exact cardinality on the *right* of `subClassOf`.
2. **Inverse properties** — `actedIn owl:inverseOf hasActor`, and similar pairs throughout the role properties. EL forbids inverses entirely.
3. **Symmetric and functional properties** — `workedWith` is symmetric, `partOfSeries` is functional. EL forbids both; QL forbids functional properties.

Conversely, we *don't* need OWL 2 Full's punning or metaclass tricks — we never treat a class as an instance, and we don't depend on undecidable constructs.

So OWL 2 DL is the **smallest standard profile that admits our axioms**. The choice was confirmed in Protégé's Profile Checker (Window → Ontology Metrics → Profiles): the ontology is reported as in OWL 2 DL but not in EL, QL, or RL.

#### Practical consequences

- We can use **HermiT**, **Pellet**, or **FaCT++** — all are complete OWL 2 DL reasoners. We picked HermiT because it ships with Protégé.
- We **cannot use ELK** (an extremely fast EL-only reasoner) — it would silently ignore our inverse properties and qualified cardinality axioms.
- We **cannot use Ontop**-style query rewriting at scale — that requires QL, which forbids cardinality.
- At this scale (305 ontology triples, 15,495 KG triples), HermiT classifies the ontology in under a second; the DL choice has no practical performance impact for us.

#### A worked example of why we exit each lighter profile

| Axiom in our ontology | Exits | Why |
|-----------------------|-------|-----|
| `Episode ⊑ ∃partOfSeries.Series ⊓ ≤1 partOfSeries.Series` (i.e., `qualifiedCardinality 1`) | EL, QL, RL | EL forbids `≤n`; QL forbids any cardinality; RL allows `≤n` only on the left of `⊑`, not the right. |
| `actedIn owl:inverseOf hasActor` | EL | EL has no inverse properties. |
| `workedWith a owl:SymmetricProperty` | EL | EL has no symmetric properties. |
| `partOfSeries a owl:FunctionalProperty` | EL, QL | Functional properties are restricted in both. |
| `Film owl:disjointWith Series` (and the AllDisjointClasses axiom over Film/Series/Episode) | — | Disjointness is allowed in all profiles in our usage; this axiom alone wouldn't push us out of EL or RL. |

Any *one* of the first four axioms is enough on its own to require OWL 2 DL.

### The Open World Assumption (OWA) — important

This is the single most counter-intuitive concept in OWL, especially if you come from databases.

- In SQL: if a row is missing, the data is missing/wrong. Constraints (NOT NULL, FK) reject incomplete data.
- In OWL: if a triple is missing, **we just don't know yet**. A reasoner never concludes "this person has no death year" from the absence of a `:deathYear` triple — it concludes "no information about death year is recorded."

Practical consequences for reading this ontology:

1. `rdfs:domain :actedIn :Actor` does **not** check that subjects of `:actedIn` are Actors. It **infers** that any subject of `:actedIn` *is* an Actor (adds a `rdf:type :Actor` triple). Domain/range axioms are inference rules, not validation rules.
2. A cardinality restriction `min 0` is a tautology — every individual already satisfies it under OWA. We removed all such empty restrictions (FIX-06).
3. To check structural completeness (CWA-style "this triple should exist"), use **SHACL** (closed-world validation language). The project does this in §10 of the report.

### Reasoner — HermiT

A reasoner is a program that derives entailed triples and checks for logical inconsistencies. Two operations matter here:

- **Classification**: compute the full inferred subclass hierarchy. E.g., from `:Actor rdfs:subClassOf :Person` and `:nm0000128 a :Actor`, infer `:nm0000128 a :Person`.
- **Consistency check**: detect whether any class is forced to be empty (unsatisfiable) by the axioms. An unsatisfiable class signals a logical bug in the ontology.

We ran HermiT in Protégé 5.6.9 on this ontology — classification succeeded, no unsatisfiable classes found, ontology is consistent.

### IRIs — hash vs. slash patterns

An IRI uniquely names a resource. There are two common patterns for ontology terms:

- **Hash URI**: `http://x.example/ontology#Film` — the part after `#` (the fragment) names the term; the whole document is dereferenced as one resource.
- **Slash URI**: `http://x.example/ontology/Film` — each term is a separate resource; the server uses HTTP 303 redirects to point at the document.

We chose **hash URIs** for the ontology because no publicly accessible server is available — dereferencing any term IRI just resolves to the local ontology document. Instance IRIs (the persons, titles, etc.) use a separate path-based pattern (`/data/{type}/{id}`) for visual separation between vocabulary and data.

### Reading the rest of this document

- **Class hierarchy** lists named classes and their parent classes (`rdfs:subClassOf`).
- **Object properties** are properties whose object is a resource (e.g., `:actedIn` connects a Person to a CreativeWork).
- **Data properties** are properties whose object is a literal (e.g., `:personName` has a string value).
- **Cardinality restrictions** state how many values a property can have for a given class (e.g., "an Episode has exactly one Series").
- **Disjointness axioms** state that classes have no individuals in common (e.g., a thing cannot be both a Film and a Series).

---

## Namespace Declarations

```turtle
@prefix : <http://cineexplorer.local/ontology#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
```

Ontology IRI: `<http://cineexplorer.local/ontology>` — hash-URI pattern (L09 Pattern 2).
Instance IRIs use a separate path-based structure: `http://cineexplorer.local/data/{type}/{id}`.

> **Why two patterns?** Vocabulary terms (`#Film`) and data instances (`/data/title/tt1707386`) are different kinds of resources. Keeping them in separate URI structures makes it visually obvious which is which, and lets us serve the ontology document from one location while delegating instance dereferencing to a Linked Data browser (Brwsr in M4).

---

## Class Hierarchy

> **How to read this**: indentation = `rdfs:subClassOf`. Annotations on the right describe additional axioms attached to each class — restrictions limit which individuals can belong, disjointness states a class shares no members with another.

```
owl:Thing
├── ce:Person                      ← subClassOf: maxCardinality(sameAsExternal, 1)
│   ├── ce:Actor
│   ├── ce:Director
│   ├── ce:Writer
│   ├── ce:Editor
│   └── ce:Composer
│   (* Person subclasses are NOT disjoint — one person may hold multiple roles *)
│
├── ce:CreativeWork                ← disjointWith: Genre, Person, Participation
│   │                                 subClassOf: maxCardinality(sameAsExternal, 1)
│   ├── ce:Film
│   ├── ce:Series                  ← rdfs:subClassOf :CreativeWork (no min-0 restriction)
│   └── ce:Episode                 ← subClassOf: qualifiedCardinality(partOfSeries, 1, Series)
│   (* Film, Series, Episode are AllDisjointClasses *)
│
├── ce:Genre                       ← disjointWith: CreativeWork, Person, Participation
│
└── ce:Participation               ← disjointWith: Genre, Person, CreativeWork
                                      subClassOf: qualifiedCardinality(playedBy, 1, Person)
                                      subClassOf: qualifiedCardinality(participatesIn, 1, CreativeWork)
```

> **Why are Film/Series/Episode disjoint, but Actor/Director are not?**
> A real-world title is exactly one of {film, series, episode} — these categories are mutually exclusive. A real person can simultaneously be an actor *and* a director (e.g., Tom Hooper directs and Russell Crowe acts; many people do both). Disjointness here would force the reasoner to reject the union, which doesn't match reality.

### OWL 2 Axioms on Classes

```turtle
# AllDisjointClasses for CreativeWork subclasses
[ a owl:AllDisjointClasses ;
  owl:members ( ce:Episode ce:Film ce:Series ) ] .

# CreativeWork disjoint axioms (inline)
ce:CreativeWork owl:disjointWith ce:Genre , ce:Person , ce:Participation .

# Participation disjoint axioms (inline)
ce:Participation owl:disjointWith ce:Genre , ce:Person , ce:CreativeWork .

# Cardinality restrictions
ce:Episode rdfs:subClassOf [
  owl:onProperty ce:partOfSeries ;
  owl:qualifiedCardinality "1"^^xsd:nonNegativeInteger ;
  owl:onClass ce:Series
] .

ce:Participation rdfs:subClassOf
  [ owl:onProperty ce:playedBy ;
    owl:qualifiedCardinality "1"^^xsd:nonNegativeInteger ;
    owl:onClass ce:Person ] ,
  [ owl:onProperty ce:participatesIn ;
    owl:qualifiedCardinality "1"^^xsd:nonNegativeInteger ;
    owl:onClass ce:CreativeWork ] .
```

> **Plain English:**
>
> - `AllDisjointClasses(Episode, Film, Series)` — no individual can belong to more than one of these three classes. If the reasoner ever encountered `:tt1 a ce:Film, ce:Series`, it would flag an inconsistency.
> - `CreativeWork owl:disjointWith Genre, Person, Participation` — same idea pairwise, but enforced individually because OWL 2 DL doesn't allow listing the four together as `AllDisjointClasses` when one is a parent of others.
> - `Episode subClassOf [partOfSeries exactly 1 Series]` — to be classified as an Episode, an individual must have exactly one `:partOfSeries` link to an instance of `:Series`. Note: this is *class-membership semantics*, not data validation. If the data omits the link, the reasoner does not flag an error — it just cannot conclude `:Episode` membership from the data alone (we assert it directly via R2RML instead).
> - `Participation subClassOf [playedBy exactly 1 Person] and [participatesIn exactly 1 CreativeWork]` — a Participation is *defined* as something with exactly one Person and one Work. This is the formal contract behind the reification pattern.

Note: `owl:minQualifiedCardinality "0"` blocks previously on `CreativeWork.hasGenre` and `Series.hasEpisode` were removed (FIX-06) — they carry no semantic content under OWA.

> **Why removing `min 0` matters:** "min 0" means "at least zero values," which is true of every individual in every model. It contributed nothing to the semantics and gave the (incorrect) impression that `hasGenre` was somehow optional in a way that other unrestricted properties weren't.

---

## Object Properties

> **What is an object property?** A binary relation whose object is itself a resource (not a literal). Example: `:nm0000128 ce:actedIn :tt1707386` — both ends are IRIs identifying real-world entities. Compare with data properties (next section), where the object is a literal value.
>
> **Property characteristics used in this ontology:**
> - `owl:inverseOf` — declares two properties as mirror images. If `A :p B` then `B :q A` is entailed (and vice versa).
> - `owl:FunctionalProperty` — at most one value per subject. If `A :p B` and `A :p C`, then B and C must be the same individual.
> - `owl:SymmetricProperty` — if `A :p B` then `B :p A` is entailed.
> - `rdfs:subPropertyOf` — every triple using the sub-property also entails a triple with the super-property. If `A :actedIn B` and `:actedIn rdfs:subPropertyOf :workedFor`, then `A :workedFor B` is entailed.

### Top-Level Navigation

| Property | Domain | Range | Notes |
|----------|--------|-------|-------|
| `ce:workedFor` | `Person` | `CreativeWork` | top property; `owl:inverseOf ce:employed` |
| `ce:employed` | `CreativeWork` | `Person` | inverse of workedFor |

> `workedFor` and `employed` are the **most general** Person↔Work relations. Every more specific role-link (`actedIn`, `directed`, `wrote`, etc.) is a sub-property of `workedFor`. This means a SPARQL query for `?p ce:workedFor ?w` retrieves everyone, regardless of role — useful for the Bacon-number queries in §9 of the report.

### Role-Specific Subproperties of `workedFor`

| Property | Domain | Range | Inverse | Source table |
|----------|--------|-------|---------|--------------|
| `ce:actedIn` | `Actor` | `CreativeWork` | `ce:hasActor` | `title_principal` (actor/actress) |
| `ce:directed` | `Director` | `CreativeWork` | `ce:directedBy` | `title_principal` (director) |
| `ce:wrote` | `Writer` | `CreativeWork` | `ce:writtenBy` | `title_principal` (writer) |
| `ce:edited` | `Editor` | `CreativeWork` | `ce:editedBy` | `title_principal` (editor) |
| `ce:composedFor` | `Composer` | `CreativeWork` | `ce:composedBy` | `title_principal` (composer) |
| `ce:knownFor` | `Person` | `CreativeWork` | — | `talent_title` |

> **Why both directions are materialised:** R2RML generates triples in the direction the mapping declares. `:actedIn` runs Person → Work, but a SPARQL query asking "who acted in this film?" wants the reverse. Without an explicit inverse, the query has to use the SPARQL inverse-path operator (`^ce:actedIn`), which complicates every query that traverses backward. The cost of materialising both directions is roughly doubling these triples in the KG; the benefit is simpler queries everywhere.
>
> **Domain effect (subtle):** Because `:actedIn` has `rdfs:domain :Actor`, asserting `:nm0000128 :actedIn :tt1707386` lets a reasoner *infer* `:nm0000128 a :Actor`. We don't rely on this in our pipeline (R2RML asserts the type directly via `<#Actor>`), but the axiom is consistent with the data.

### Participation Links

| Property | Domain | Range | Semantics |
|----------|--------|-------|-----------|
| `ce:playedBy` | `Participation` | `Person` | Person in this credit |
| `ce:hasRole` | `Person` | `Participation` | Inverse of playedBy |
| `ce:participatesIn` | `Participation` | `CreativeWork` | Title of this credit |

> **What is a Participation?** Reification — a formal pattern for turning a relation into a first-class node so it can carry its own attributes. Instead of just saying `:nm0000128 :actedIn :tt1707386`, we mint a node `:participation/tt1707386/nm0000128/3` and attach to *it* the character name, the credit order, the job title, etc. This avoids the "where do I put the character name?" problem (it doesn't belong to the actor in general or the film in general — it belongs to *this credit* on *this film*).

### Series / Episode Hierarchy

| Property | Domain | Range | OWL annotation |
|----------|--------|-------|----------------|
| `ce:hasEpisode` | `Series` | `Episode` | inverse of partOfSeries |
| `ce:partOfSeries` | `Episode` | `Series` | `owl:FunctionalProperty` |

> **`partOfSeries` is functional**: an Episode belongs to exactly one Series. If the data ever asserted `:ep1 :partOfSeries :series_a, :series_b`, the reasoner would conclude `:series_a owl:sameAs :series_b` (or flag a contradiction if the two series are also asserted disjoint).

### Cross-Cutting

| Property | Domain | Range | OWL annotation |
|----------|--------|-------|----------------|
| `ce:hasGenre` | `CreativeWork` | `Genre` | inverse of isGenreOf |
| `ce:isGenreOf` | `Genre` | `CreativeWork` | — |
| `ce:workedWith` | `Person` | `Person` | `owl:SymmetricProperty`; NOT materialized in mapping (derivable via Participation) |
| `ce:sameAsExternal` | — | — | vocabulary-level declaration; populated at M4 query time via Wikidata P345 federation |

> **`workedWith` is symmetric but not materialised.** The symmetric axiom says "if A worked with B, then B worked with A." Materialising it from `title_principal` would generate O(n²) triples per shared title, in both directions, plus the symmetry already entailed. We instead derive `workedWith` at SPARQL query time from shared `Participation` nodes — a property-path expression in the query reproduces the relation without the storage cost. The ontology declaration remains as a *semantic annotation*: a downstream tool that does want to materialise it knows the property is symmetric.
>
> **`sameAsExternal`** is a custom alignment property pointing at non-local resources (e.g., Wikidata Q-IDs). We did not pre-materialise these links in the mapping. Instead, M4's Q7 federated query joins to Wikidata at runtime via Wikidata property P345 (which stores IMDb `nconst` values — the same IDs embedded in our person IRIs). The ontology declaration documents the intent; the data side fills it in on demand.

---

## Data Properties

> **What is a data property?** A property whose object is a literal value (string, number, date, boolean) rather than a resource. Each data property has an `rdfs:range` declaring the expected XSD datatype — used by reasoners and by SPARQL when evaluating typed comparisons.

### On `Person`

| Property | Range | Notes |
|----------|-------|-------|
| `ce:personName` | `xsd:string` | TALENT_NAME |
| `ce:birthYear` | `xsd:gYear` | BIRTH_YEAR |
| `ce:deathYear` | `xsd:gYear` | DEATH_YEAR |

`ce:personProperties` removed (FIX-02) — career roles are captured by subclass type assertions.

> **`xsd:gYear`** is the W3C type for a calendar year alone (e.g., `"1964"^^xsd:gYear`). Using it instead of `xsd:int` lets SPARQL date filters work correctly.

### On `CreativeWork`

| Property | Range | Notes |
|----------|-------|-------|
| `ce:workTitle` | `xsd:string` | PRIMARY_TITLE |
| `ce:originalTitle` | `xsd:string` | ORIGINAL_TITLE — added FIX-02 |
| `ce:releaseYear` | `xsd:gYear` | START_YEAR |
| `ce:runtimeMinutes` | `xsd:nonNegativeInteger` | RUNTIME_MINUTES |
| `ce:isAdult` | `xsd:boolean` | IS_ADULT |
| `ce:language` | `xsd:string` | ISO language code from `title_aka.LANGUAGE_ID` |
| `ce:region` | `xsd:string` | ISO region code from `title_aka.REGION_ID` |

`ce:creativeWorkProperties` removed (FIX-02). Content type captured by `rdf:type`.

> **Why content type is `rdf:type` and not a data property:** `Film`, `Series`, `Episode` are *classes*, not values of an attribute. Modelling them as a string attribute (e.g., `:contentType "movie"`) would prevent SPARQL queries from using class-based reasoning and would make subclass relationships invisible to a reasoner. The class-based representation is more expressive at no extra cost.

### On `Series`

| Property | Range | Notes |
|----------|-------|-------|
| `ce:endYear` | `xsd:gYear` | END_YEAR — added FIX-02, domain Series only |

> Note `endYear` is on `Series` specifically (not `CreativeWork`), because films and episodes don't have a meaningful end year — only series do.

### On `Episode`

| Property | Range | Notes |
|----------|-------|-------|
| `ce:seasonNumber` | `xsd:nonNegativeInteger` | SEASON_NUMBER |
| `ce:episodeNumber` | `xsd:nonNegativeInteger` | EPISODE_NUMBER |

`ce:episodeProperties` removed (FIX-02); `ce:originalTitle` (from `CreativeWork`) covers it.

### On `Genre`

| Property | Range | Notes |
|----------|-------|-------|
| `ce:genreName` | `xsd:string` | GENRE_NAME |

### On `Participation`

| Property | Range | Notes |
|----------|-------|-------|
| `ce:characterName` | `xsd:string` | From `principal_role` (1NF-normalized) |
| `ce:participationRole` | `xsd:string` | CATEGORY_NAME (e.g., "actor", "director") |
| `ce:participationProperties` | `xsd:string` | JOB (free-text job description) |

> **Why is `characterName` on `Participation` rather than on `Actor` or `Person`?** Because a single actor can play different characters across different credits (Tom Hanks plays Forrest Gump in one film, Captain Phillips in another). The character name is a property of the *credit*, not of the actor in general. Reification gives us a node to attach it to.

---

## General Axioms

```turtle
# AllDisjointClasses
[ a owl:AllDisjointClasses ;
  owl:members ( ce:Episode ce:Film ce:Series ) ] .

# NOTE: Person subclasses are intentionally NOT disjoint.
# A person can be both an Actor and a Director simultaneously.
```

---

## Design Decisions (Current)

> Each decision below records *why* the ontology looks the way it does. These are the answers most readers (and the professor) will ask about.

1. **Participation reification** — `ce:Participation` is a contextual node carrying `characterName`, `participationRole`, and `participationProperties`. Enables richer querying than direct person→work properties alone.

   > *Without reification*, character names and credit-order metadata would have nowhere to attach. We'd either lose them, force them onto the actor (wrong — they're per-credit), or force them onto the film (wrong — they're per-actor-on-this-film). Reification is the standard semantic-web pattern for this.

2. **Role-specific subproperties** — `actedIn`, `directed`, `wrote`, `edited`, `composedFor` are materialized as direct properties for query convenience, even though derivable via `Participation`.

   > *Pure-Participation alternative*: `?p ce:hasRole ?par . ?par ce:participatesIn ?w ; ce:participationRole "actor" .` This works but is verbose. Materialising the direct properties shortens every query. The trade-off is more triples in the KG (acceptable at this scale).

3. **Person subclasses not disjoint** — A real person can be both Actor and Director.

   > See the explanation in the Class Hierarchy section. Disjointness here would falsely reject reality (Clint Eastwood, Greta Gerwig, Tom Hooper, etc.).

4. **`workedWith` as semantic annotation only** — declared `owl:SymmetricProperty` in the ontology but NOT materialized in the mapping (FIX-03 removed the self-join triple map). Derivable at query time via shared `Participation` nodes.

   > See the property-table explanation above. Materialisation is O(n²) per title — wasteful for a relation that is recomputable in SPARQL with one `Participation` join.

5. **`language`/`region` as ISO literals** — store ISO codes (`LANGUAGE_ID`, `REGION_ID`) directly as string literals; no `Language`/`Region` classes (FIX-04, Option A confirmed by professor feedback).

   > Treating language as a class would let us attach metadata (native name, language family, …) but the queries we care about only need to filter and group by language — string codes are sufficient. The professor confirmed the simpler choice was appropriate.

6. **`sameAsExternal`** — kept as vocabulary-level declaration; Wikidata alignment performed at M4 query time via SPARQL federation using Wikidata property P345.

   > Pre-materialising `sameAsExternal` triples would freeze the alignment at mapping-time and require regeneration whenever Wikidata adds new persons. Using federation, the alignment is always live and zero-cost in our KG. The ontology vocabulary is still there for downstream consumers who might want to materialise it.

---

## Reading OWL Axioms — Cheat Sheet

| Construct | Plain English |
|-----------|---------------|
| `:A rdfs:subClassOf :B` | Every A is a B. |
| `:A owl:disjointWith :B` | Nothing is both A and B. |
| `:p rdfs:domain :A` | If `?x :p ?y`, then `?x` is an A (inferred). |
| `:p rdfs:range :A` | If `?x :p ?y`, then `?y` is an A (inferred). |
| `:p owl:inverseOf :q` | `?x :p ?y` iff `?y :q ?x`. |
| `:p a owl:FunctionalProperty` | Each subject has at most one value of `:p`. |
| `:p a owl:SymmetricProperty` | `?x :p ?y` iff `?y :p ?x`. |
| `:p rdfs:subPropertyOf :q` | Every `?x :p ?y` triple also entails `?x :q ?y`. |
| `:A subClassOf [onProperty :p ; qualifiedCardinality "1" ; onClass :B]` | Every A has exactly one `:p` value, and that value is a B. |
| `[ a AllDisjointClasses ; members (:A :B :C) ]` | A, B, C are pairwise disjoint. |

> **Reminder**: under the Open World Assumption, all of these are *inference rules and consistency conditions*, not validation rules. Missing data is never an error to a reasoner — it just limits what can be entailed. To enforce structural completeness on the data, we use SHACL (see report §10).

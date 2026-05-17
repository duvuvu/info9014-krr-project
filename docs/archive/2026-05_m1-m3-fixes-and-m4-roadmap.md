# CineExplorer — Fix Plan & Milestone 4 Roadmap

## Part 1 — Fixes for M2 (Ontology) and M3 (Mapping)

These are issues identified from self-review and professor feedback. Each fix has a clear scope.

Status values: `Waitlist` → `Approved` → `Solved`

| Fix | Description | Priority | Status | Notes |
|-----|-------------|----------|--------|-------|
| FIX-01 | Namespace (`example.org` → proper namespace) | HIGH | Solved | Implement with FIX-09 |
| FIX-02 | Remove concat literals (`personProperties`, `creativeWorkProperties`) | HIGH | Solved | Implement with FIX-12, FIX-13 (all touch §7.3) |
| FIX-03 | Remove `workedWith` from mapping | MEDIUM | Solved | |
| FIX-04 | `language`/`region`: switch to ISO codes (Option A — keep as literals) | MEDIUM | Solved | |
| FIX-05 | `sameAsExternal` — reframe as query-time federation (report only, defer to M4) | MEDIUM | Solved | Resolved at M4 via Q7 Wikidata federation (`sparql/q07_wikidata_federation.sparql`) using BIND+REPLACE+SERVICE; no mapping materialisation needed |
| FIX-06 | Rewrite §6.5 Encountered Problems + remove min-0 restrictions from ontology | MEDIUM | Solved | |
| FIX-07 | Remove `played` property and triple map | LOW | Solved | |
| FIX-08 | Rewrite §6.3 OWL Profile (wrong HermiT + OWL 2 Full statements) | MEDIUM | Solved | |
| FIX-09 | Rewrite §6.4 Namespace and IRIs (IRI justification + naming conventions) | MEDIUM | Solved | Implement with FIX-01 |
| FIX-10 | Rewrite §7.2 IRI Strategy (surrogate keys phrase + ORD justification) | LOW | Solved | |
| FIX-11 | Add `rdfs:label` to Participation instances in mapping + mention in report | MEDIUM | Solved | |
| FIX-12 | Explain template-based joins vs. RefObjectMap in §7.3 | MEDIUM | Solved | Implement with FIX-02, FIX-13 (all touch §7.3) |
| FIX-13 | Address `principal_role` — **overall M3 feedback**, show real-world R2RML awareness | CRITICAL | Solved | Implement with FIX-02, FIX-12 (all touch §7.3) |
| FIX-14 | Add forward reference to deployment and reasoning at end of §7 | LOW | Solved | |

---

### FIX-01 · Namespace (HIGH) — `Solved`
**Files:** `cineexplorer_ontology.ttl`, `mapping/cineexplorer_mapping.ttl`, all IRI templates
**Implement with:** FIX-09 (report §6.4 text uses the new namespace)

**Problem:** `https://example.org/cineexplorer/ontology#` uses `example.org`, which is
IANA-reserved and non-dereferenceable. The project guidelines require "a well-chosen namespace."

**Decided namespace:**
- Ontology terms: `http://cineexplorer.local/ontology#` (hash-URI pattern, L09 Pattern 2)
- Data instances: `http://cineexplorer.local/data/`

**Changes required:**
1. `cineexplorer_ontology.ttl` line 1: replace `@prefix : <https://example.org/cineexplorer/ontology#>`
2. `cineexplorer_ontology.ttl` line 7: replace `@base <https://example.org/cineexplorer/ontology#>`
3. `cineexplorer_ontology.ttl` line 9: replace `<https://example.org/cineexplorer/ontology> rdf:type owl:Ontology` → `<http://cineexplorer.local/ontology> rdf:type owl:Ontology`
4. `mapping/cineexplorer_mapping.ttl` line 10: replace `@prefix ce: <https://example.org/cineexplorer/ontology#>`
5. Every `rr:template` string in the mapping (~22 maps): replace `https://example.org/cineexplorer/` with `http://cineexplorer.local/data/`
6. Comment block in mapping lines 17–20: update the IRI examples in the comment to match the new namespace
7. Report §6.4 (via FIX-09): update the namespace shown in text

---

### FIX-02 · Remove `personProperties` and `creativeWorkProperties` (HIGH) — `Solved`
**File:** `cineexplorer_ontology.ttl`, `mapping/cineexplorer_mapping.ttl`

**Problem:** Both properties pack multiple attribute values into a single literal string,
re-introducing a 1NF violation at the RDF level — exactly the anti-pattern fixed in M1.

**Professor feedback (confirmed):**
- `#PersonProperties`: "Why are you denormalizing data? Now I can't query for specific roles." — the `GROUP_CONCAT` result is an opaque string; a SPARQL query cannot filter on a specific role name without string matching.
- `creativeWorkProperties` template: "Why are you making information non-atomic? Also, what happens when one of these three values is null? Have you looked at the spec?" — R2RML §10.3 states that if **any** column referenced in an `rr:template` is NULL, the entire triple is skipped. So if `ORIGINAL_TITLE` is NULL, the triple is dropped even when `END_YEAR` and `CONTENT_TYPE_NAME` have values. Mapping them as separate `rr:column` predicateObjectMaps avoids this: each is independently skipped only when its own column is NULL.

**Proposed changes — ontology (`cineexplorer_ontology.ttl`):**
- Remove `ce:personProperties` data property (lines 204–208)
- Remove `ce:creativeWorkProperties` data property (lines 246–250)
- Remove `ce:episodeProperties` data property (lines 264–268)
- Add new data property `ce:originalTitle` (domain `ce:CreativeWork`, range `xsd:string`)
- Add new data property `ce:endYear` (domain `ce:Series`, range `xsd:gYear`)

```turtle
:originalTitle rdf:type owl:DatatypeProperty ;
    rdfs:domain :CreativeWork ;
    rdfs:range xsd:string ;
    rdfs:label "original title"@en ;
    rdfs:comment "Original title of a creative work, when different from the primary title."@en .

:endYear rdf:type owl:DatatypeProperty ;
    rdfs:domain :Series ;
    rdfs:range xsd:gYear ;
    rdfs:label "end year"@en ;
    rdfs:comment "Year in which a series concluded, when known."@en .
```

**Proposed changes — mapping (`mapping/cineexplorer_mapping.ttl`):**

In `<#Film>` — remove `creativeWorkProperties` block (lines 70–73), add:
```turtle
rr:predicateObjectMap [
  rr:predicate ce:originalTitle ;
  rr:objectMap [ rr:column "ORIGINAL_TITLE" ; rr:datatype xsd:string ]
] ;
```

In `<#Series>` — same removal + same `originalTitle` addition + add:
```turtle
rr:predicateObjectMap [
  rr:predicate ce:endYear ;
  rr:objectMap [ rr:column "END_YEAR" ; rr:datatype xsd:gYear ]
] ;
```

In `<#Episode>` — remove `episodeProperties` block (lines 184–187), add `originalTitle` only (no endYear on Episode).

Remove entire `<#PersonProperties>` triple map (lines 381–398).

**Proposed changes — report (`report/sec/7_mapping.tex`):**
- §7.3 creative works paragraph: mention `ce:originalTitle` is mapped as a separate property; note that `contentType` is captured by `rdf:type`
- §7.3 persons paragraph: remove any mention of `personProperties`; note that role subclass membership already encodes career roles
- Encountered Problems (commented out section): add a note that the original concat approach was revised after recognising the NULL-propagation behaviour specified in R2RML §10.3

---

### FIX-03 · Remove `workedWith` from mapping (MEDIUM) — `Solved`
**File:** `mapping/cineexplorer_mapping.ttl`

**Problem:** `workedWith` is materialized via a self-join on `title_principal` that generates
O(n²) pairs and does not respect symmetry (both directions are materialized). It is derivable
from `Participation` via SPARQL property paths.

**Fix:** Remove the `<#WorkedWith>` triple map entirely. In the report, explain that
`workedWith` is a derived/query-time relation, illustrate with a SPARQL query.
Keep `owl:SymmetricProperty` declaration in the ontology as a semantic annotation.

---

### FIX-04 · Keep `language`/`region` as literals, switch to ISO codes (MEDIUM) — `Solved`
**File:** `mapping/cineexplorer_mapping.ttl`, `report/sec/7_mapping.tex`

**Decision: Option A — keep as data property literals, but use ISO codes.**
Professor M2 feedback: "Why do you want to model languages? I.e., why are language tags
not sufficient?" — this confirms that creating Language/Region classes is not required.
The current mapping uses full names (`LANGUAGE_NAME`, `REGION_NAME`); switching to
ISO codes (`LANGUAGE_ID`, `REGION_ID`) already in `title_aka` is cleaner and more
interoperable, without adding structural complexity.

**No ontology changes** — `ce:language` and `ce:region` remain as data properties.

**Mapping changes — `<#TitleLanguage>` (lines 773–790):**
```diff
- SELECT DISTINCT ta.TITLE_ID, l.LANGUAGE_NAME
- FROM title_aka ta
- JOIN language l ON ta.LANGUAGE_ID = l.LANGUAGE_ID
- WHERE ta.LANGUAGE_ID IS NOT NULL
-   AND l.LANGUAGE_NAME IS NOT NULL
+ SELECT DISTINCT ta.TITLE_ID, ta.LANGUAGE_ID
+ FROM title_aka ta
+ WHERE ta.LANGUAGE_ID IS NOT NULL
  ...
- rr:objectMap [ rr:column "LANGUAGE_NAME" ; rr:datatype xsd:string ]
+ rr:objectMap [ rr:column "LANGUAGE_ID" ; rr:datatype xsd:string ]
```

**Mapping changes — `<#TitleRegion>` (lines 792–809), same pattern:**
```diff
- SELECT DISTINCT ta.TITLE_ID, r.REGION_NAME
- FROM title_aka ta
- JOIN region r ON ta.REGION_ID = r.REGION_ID
- WHERE ta.REGION_ID IS NOT NULL
-   AND r.REGION_NAME IS NOT NULL
+ SELECT DISTINCT ta.TITLE_ID, ta.REGION_ID
+ FROM title_aka ta
+ WHERE ta.REGION_ID IS NOT NULL
  ...
- rr:objectMap [ rr:column "REGION_NAME" ; rr:datatype xsd:string ]
+ rr:objectMap [ rr:column "REGION_ID" ; rr:datatype xsd:string ]
```

**Report change — `report/sec/7_mapping.tex` (line 76):**
Replace the current sentence with:
```latex
Language and region are attached as ISO-coded string attributes to \texttt{CreativeWork}
instances via \texttt{ce:language} and \texttt{ce:region}. Modelling them as
independent classes would add structural complexity without benefit for the queries
in this project; typed string codes are sufficient to filter and group works by
language or region in SPARQL.
```

---

### FIX-05 · `sameAsExternal` — reframe as query-time federation (MEDIUM) — `Solved`
**File:** `report/sec/7_mapping.tex` (one sentence); full Wikidata integration delivered in M4
**Deferred to:** M4 report writing

**Decision:** No mapping changes. Wikidata alignment is performed at query time using
SPARQL federation (SERVICE → Wikidata) via Wikidata property P345 (IMDb person ID),
which stores the same `nconst` values already embedded in our person IRIs. This is
demonstrated in §9 (SPARQL queries). `ce:sameAsExternal` remains in the ontology as
a vocabulary-level declaration.

**Report change — update the sentence in the report that promises materialized links:**
Replace any text implying `sameAsExternal` triples will be generated in the mapping with:
```latex
Alignment with external resources such as Wikidata is supported at query time via
SPARQL federation using Wikidata property P345 (IMDb person identifier), as described
in Section~\ref{sec:sparql}.
```

---

### FIX-06 · Rewrite §6.5 Encountered Problems (MEDIUM) — `Solved`
**File:** `report/sec/6_ontology-engineering.tex` (lines 95–99), `cineexplorer_ontology.ttl` (lines 334–338, 354–358)

**Problems:**
- Section is only 2 sentences — project guidelines require: tooling, task distribution, conflict resolution, technical and non-technical challenges
- Professor feedback: "improve graph usability" → "ref?" — this is a vague claim used as a design justification, not a citable fact. Must be replaced with concrete reasoning.
- **Factual inconsistency:** The current report line 99 says "Cardinality expressions of the form min~0 were removed" — but they still exist in the ontology: `owl:minQualifiedCardinality "0"` is present on `CreativeWork.hasGenre` (ontology lines 334–338) and `Series.hasEpisode` (lines 354–358). These are semantically empty (min 0 is always satisfied under OWA) so they should actually be removed as part of this fix.

**Current text (lines 95–99):**
```
\subsection{Encountered Problems}

A main challenge was handling directionality of relations. Explicit inverse properties
were introduced to support bidirectional navigation and improve graph usability.

Another issue concerned redundant axioms. Cardinality expressions of the form
\texttt{min~0} were removed, as they do not contribute semantic information.
```

**Proposed replacement:**
```latex
\subsection{Encountered Problems}

\paragraph{Tooling.}
The ontology was developed in Protégé 5.6.9 using the HermiT reasoner for consistency
checking and classification. An early version of the ontology triggered an
unsatisfiability due to a conflicting disjointness axiom on \texttt{Participation};
this was resolved by narrowing the disjointness to the intended classes only.

\paragraph{Property directionality.}
R2RML generates triples in the direction defined by the mapping template. A property
such as \texttt{ce:actedIn} (\texttt{Person} $\to$ \texttt{CreativeWork}) requires a
separate triple map for its inverse \texttt{ce:hasActor} if queries need to traverse
from work to person. Explicit inverse properties were therefore introduced for each
role-specific property to avoid requiring \texttt{OPTIONAL \{ ?w \^{}ce:actedIn ?p \}}
patterns in every query.

\paragraph{Participation vs.\ direct properties.}
An initial design used only direct role-specific properties between \texttt{Person} and
\texttt{CreativeWork}. The \texttt{Participation} reification was introduced to allow
contextual attributes --- character name, job description, credit order --- to be
attached to the relation itself rather than to either endpoint. This decision increased
the number of triple maps but improved the expressiveness of the model.

\paragraph{Cardinality and the open-world assumption.}
Early drafts included \texttt{owl:minQualifiedCardinality "0"} restrictions, which
were removed as they carry no semantic information (zero is the default under the
open-world assumption). The retained cardinality axioms (e.g., exactly one
\texttt{partOfSeries} per \texttt{Episode}) define class membership conditions, not
data completeness constraints.
```

**Ontology changes required (alongside the report rewrite):**
Remove the two `owl:minQualifiedCardinality "0"` restriction blocks from `cineexplorer_ontology.ttl`:
- Lines 334–338 on `CreativeWork` (the `hasGenre` min 0 restriction)
- Lines 354–358 on `Series` (the `hasEpisode` min 0 restriction)

These carry no semantic content and removing them makes the report claim true.

---

### FIX-07 · Remove `played` property and triple map (LOW) — `Solved`
**Files:** `cineexplorer_ontology.ttl`, `mapping/cineexplorer_mapping.ttl`

**Problem:** `ce:played` and `ce:actedIn` are both subproperties of `workedFor` with identical
domain (`Actor`) and range (`CreativeWork`). The distinction is unclear and the mapping
confirms they use the exact same SQL query. One is redundant.

**Changes applied:**
1. `cineexplorer_ontology.ttl`: removed the `:played` ObjectProperty block (was at lines 171–177 after earlier fixes — plan's original line numbers were stale)
2. `mapping/cineexplorer_mapping.ttl`: removed the entire `<#Played>` triple map and its section header (was lines 769–792)
3. `report/sec/7_mapping.tex`: no change needed — the list of direct traversal properties at line 88 already omits `played` (removed during an earlier pass)

**Verification:** KG regenerated successfully. Triple count dropped from 15,495 → 15,255 (−240 triples = the 240 actor–title pairs that `<#Played>` had duplicated from `<#ActedIn>`). Zero `ce:played` predicates remain in the KG; `ce:playedBy` (Participation→Person, distinct property) is unaffected. No SPARQL query in `sparql/` referenced `ce:played`.

---

### FIX-08 · Rewrite §6.3 OWL Profile (MEDIUM) — `Solved`
**File:** `report/sec/6_ontology-engineering.tex` (lines 58–69)

**Problem (professor feedback):**
- "The ontology was successfully classified" → professor asks: what does this mean?
- "indicating that no OWL 2 Full constructs are used" → wrong logic. OWL 2 Full is a superset of OWL 2 DL (more permissive, not stricter). HermiT running successfully does not imply anything about OWL 2 Full — HermiT simply does not operate over OWL 2 Full. The correct verification is Protégé's OWL Profile Checker.
- Red highlight on "cardinality axioms describe intended meaning rather than enforce completeness of data" → statement is true but dropped in without explanation or example.

**Fix:** Rewrite the entire subsection:
1. Keep OWL 2 DL as the profile — it is correct. Add a bulleted list of which constructs require DL (qualified cardinality, disjointness, symmetric/functional properties) and which profiles they rule out.
2. Replace the HermiT sentence with: (a) Profile Checker confirms OWL 2 DL; (b) HermiT classification = reasoner computed inferred class hierarchy and found no unsatisfiable classes → ontology is consistent.
3. Replace the vague OWA sentence with a concrete example using `ce:partOfSeries` / `ce:Episode`.

**No ontology or mapping changes needed — report only.**

---

### FIX-09 · Rewrite §6.4 Namespace and IRIs (MEDIUM) — `Solved`
**File:** `report/sec/6_ontology-engineering.tex` (lines 91–93)
**Depends on:** FIX-01 (namespace value changes) — implement together

**Professor feedback:**
- Highlighted entire subsection: "Why this approach for IRIs?"
- "standard conventions" → "? What standard?"

**Why it is a problem:**
1. The current text states the namespace but gives no justification for the design choice. L09 (Linked Data) covers 4 URI patterns for non-information resources — the report never says which pattern was selected or why. A reader cannot evaluate the IRI design without this explanation.
2. There is no formal standard (no ISO/W3C mandate) for UpperCamelCase classes / lowerCamelCase properties. The word "standard" is incorrect. The accurate term is "convention", sourced from how the W3C OWL vocabulary itself is named (e.g., `owl:ObjectProperty`, `owl:hasValue`). The W3C OWL 2 Primer and "Cool URIs for the Semantic Web" are the citable references.

**Proposed replacement text for lines 91–93:**

```latex
\subsection{Namespace and IRIs}

The ontology uses a hash URI pattern~\cite{cooluris} with a single namespace:
\texttt{http://cineexplorer.local/ontology\#}. Under this pattern, each ontology term
is identified by a URI fragment (e.g.,
\texttt{http://cineexplorer.local/ontology\#Film}), and dereferencing any term IRI
resolves to the ontology document. This avoids the HTTP 303 redirect infrastructure
required by slash URI patterns, making it appropriate for a locally deployed academic
project where a publicly accessible server is not available.

Instance IRIs follow a separate path-based structure:
\texttt{http://cineexplorer.local/data/\{type\}/\{id\}}, reusing the stable IMDb
identifiers from the source dataset as local names. The IRI design is described
further in Section~\ref{sec:mapping}.

Class and property names follow the naming conventions used throughout the W3C OWL
vocabulary~\cite{owl2primer}: UpperCamelCase for class names
(e.g., \texttt{CreativeWork}, \texttt{Participation}) and lowerCamelCase for property
names (e.g., \texttt{workedFor}, \texttt{partOfSeries}). All terms carry
\texttt{rdfs:label} and \texttt{rdfs:comment} annotations in English.
```

**New bibliography entries needed in `report/references.bib`:**

```bibtex
@techreport{cooluris,
  author      = {Leo Sauermann and Richard Cyganiak},
  title       = {{Cool URIs for the Semantic Web}},
  institution = {World Wide Web Consortium (W3C)},
  year        = {2008},
  type        = {W3C Interest Group Note},
  url         = {https://www.w3.org/TR/cooluris/}
}

@techreport{owl2primer,
  author      = {Pascal Hitzler and Markus Kr{\"o}tzsch and Bijan Parsia and Peter F. Patel-Schneider and Sebastian Rudolph},
  title       = {{OWL 2 Web Ontology Language Primer (Second Edition)}},
  institution = {World Wide Web Consortium (W3C)},
  year        = {2012},
  type        = {W3C Recommendation},
  url         = {https://www.w3.org/TR/owl2-primer/}
}
```

**Note:** The subsection title changes from "Namespace and Documentation" to "Namespace and IRIs" to better reflect the content. The `example.org` value in the text will be updated to `http://cineexplorer.local/ontology#` as part of FIX-01.

---

### FIX-10 · Rewrite §7.2 IRI Strategy — surrogate keys + ORD justification (LOW) — `Solved`
**File:** `report/sec/7_mapping.tex` (lines 21 and 40–43)
**Scope:** covers both IRI surrogate-key phrasing (§7.2 line 21) and ORD justification (§7.2 lines 40–43)

**Professor feedback:**
- Line 21: "Quid? Did you add artificial keys in the existing database?"
- Lines 40–43: "Is ORD necessary here? Are there title_id/talent_id combinations with multiple occurrences? If yes, what does that mean?"

**Why it is a problem:**
1. "Rather than on surrogate numeric keys generated by our schema" implies we considered adding artificial PKs to the database — which we never did. It is confusing and misleading.
2. "ORD is the credit order from `title_principal`" states the fact but never justifies why it is needed in the IRI. A person CAN have multiple credits on the same title (e.g., director AND actor), producing multiple rows with the same `TITLE_ID`/`TALENT_ID` but different `ORD` and `CATEGORY_ID`. Without `ORD`, these would collapse into one Participation node.

**Proposed fix 1 — replace line 21:**

Current:
```
IRIs are based on the IMDb identifiers already present in the database, rather than on
surrogate numeric keys generated by our schema.
```
Replace with:
```latex
IRIs reuse the IMDb identifiers already present in the source data: \texttt{tconst}
values for titles and \texttt{nconst} values for persons. These identifiers are stable,
globally recognised, and make it unnecessary to introduce any additional keys into the schema.
```

**Proposed fix 2 — replace part of lines 40–43:**

The itemize block ends at line 41 (`\end{itemize}`), then line 43 contains two sentences:
`For genres, an internal identifier is used because the source data does not provide IMDb-style identifiers for genre instances. The participation IRI is composite because a participation record is context-dependent: it is identified by the work, the person, and the credit order.`

Keep the genre sentence. Replace the Participation sentence and the ORD line inside the itemize:

Current (line 40, inside itemize item):
```
    where \texttt{ORD} is the credit order from the \texttt{title\_principal} table.
```
Current (line 43, second sentence only):
```
The participation IRI is composite because a participation record is context-dependent:
it is identified by the work, the person, and the credit order.
```

Replace both with:
```latex
where \texttt{ORD} is the credit order from the \texttt{title\_principal} table.
The primary key of \texttt{title\_principal} is the triple
(\texttt{TITLE\_ID}, \texttt{TALENT\_ID}, \texttt{ORD}), because the same person can
hold more than one credit on the same title --- for example, a person credited as both
director and actor generates two rows with the same \texttt{TITLE\_ID} and
\texttt{TALENT\_ID} but different \texttt{ORD} and \texttt{CATEGORY\_ID} values.
Omitting \texttt{ORD} from the IRI template would collapse these into a single node,
losing the distinction between credits.
```

**Report only — no mapping changes.**

---

### FIX-11 · Add `rdfs:label` to Participation instances (MEDIUM) — `Solved`
**File:** `mapping/cineexplorer_mapping.ttl`, `report/sec/7_mapping.tex`

**Professor feedback:** "Have you thought about labels and comments for your instances?"

**Why it is a problem:**
The mapping generates `rdfs:label` for Film, Series, Episode, Person, and Genre — but **not** for Participation nodes. A Participation IRI like `http://cineexplorer.local/participation/tt0000001/nm0000001/1` has no human-readable label, making it opaque in SPARQL results and Linked Data browsers.

**Proposed fix — mapping (`<#Participation>` triple map):**
The `<#Participation>` map currently ends at line 442 with `] .` (closing period). The label block must be inserted INSIDE the map — change the `;` after the `participationProperties` block (line 441) to keep the semicolon, then add the new block before the closing `. `:

```turtle
  rr:predicateObjectMap [
    rr:predicate ce:participationProperties ;
    rr:objectMap [ rr:column "JOB" ; rr:datatype xsd:string ]
  ] ;
  rr:predicateObjectMap [
    rr:predicate rdfs:label ;
    rr:objectMap [
      rr:template "{CATEGORY_NAME} of {TALENT_ID} in {TITLE_ID}" ;
      rr:language "en"
    ]
  ] .
```
This produces labels like `"actor of nm0000128 in tt0000001"@en` — readable and queryable.

**Proposed fix — report §7.3 (add one sentence to the Participation paragraph):**
```
Each participation node carries an \texttt{rdfs:label} constructed from the
category name and the IMDb identifiers of the person and title, providing a
human-readable identifier for use in SPARQL results and Linked Data browsers.
```

---

### FIX-12 · Explain template-based joins vs. RefObjectMap (MEDIUM) — `Solved`
**File:** `report/sec/7_mapping.tex` §7.3

**Professor feedback:** "Why are you not using referencing-object maps? What are the advantages and disadvantages of your approach?"

**Why it is a problem:**
R2RML defines `rr:RefObjectMap` with `rr:joinCondition` as the standard mechanism for expressing foreign-key joins between logical tables (L08, EX05 §4). Our mapping instead links related resources by constructing matching IRIs on both sides using `rr:template`. The report never acknowledges this design choice or its tradeoffs, so the professor cannot evaluate whether it was deliberate or accidental.

**RefObjectMap vs. template-based — the tradeoff:**

A RefObjectMap for `<#Episode>.partOfSeries` would look like:
```turtle
rr:predicateObjectMap [
  rr:predicate ce:partOfSeries ;
  rr:objectMap [
    rr:parentTriplesMap <#Series> ;
    rr:joinCondition [ rr:child "PARENT_TITLE_ID" ; rr:parent "TITLE_ID" ]
  ]
] .
```
Our approach uses:
```turtle
rr:objectMap [
  rr:template "http://cineexplorer.local/data/title/{PARENT_TITLE_ID}" ;
  rr:termType rr:IRI
]
```

| | Template-based (our approach) | RefObjectMap |
|--|--|--|
| Works when | IRI pattern is uniform across all maps | Always — join is explicit |
| Coupling | Tight — IRI pattern must match exactly | Loose — join logic is separate from IRI |
| Portability | Depends on consistent template naming | Fully portable |
| SQL executed | One query per map | Engine performs the join |

**Proposed addition to §7.3 (new paragraph after the creative works paragraph):**
```latex
\paragraph{Template-based joins.}
Cross-entity links such as \texttt{ce:partOfSeries} and \texttt{ce:hasGenre} are
expressed using matching \texttt{rr:template} patterns on both sides rather than
\texttt{rr:RefObjectMap} with explicit join conditions. This is possible because all
entities of the same type share a single IRI template: any map that knows a
\texttt{TITLE\_ID} can construct the correct title IRI without needing a formal join.
The advantage is simplicity --- no join overhead and no dependency on the logical table
structure. The disadvantage is tight coupling: if the IRI template for one entity type
were to change, every map that references it via template would also need to be updated.
An \texttt{rr:RefObjectMap} approach would localise that change to a single parent map.
```

**Report only — no mapping changes needed.**

---

### FIX-13 · Address `principal_role` table creation — overall M3 feedback (CRITICAL) — `Solved`
**File:** `report/sec/7_mapping.tex` (line 62 + §7.1 Approach)

**Professor feedback (overall M3):** "The goal was NOT to change the tables. Do you think you are allowed to change an existing database's structure in practice? The ERD is to help you understand the data."
**Also inline on line 62** (same text).

**Weight:** This is the professor's overall feedback for the entire M3 submission — the central criticism of the milestone. The fix must be prominent, not buried in one sentence.

**What the professor means:**
In a real R2RML project, the source database is read-only. The mapping must work with the schema as delivered. The ERD represents what you are given — not a starting point to redesign. Creating `principal_role` as a new table violates this principle. The professor expects the report to show awareness of this constraint and demonstrate that the correct production approach is understood.

**The practical constraint:**
`title_principal_raw` (which held the original comma-separated `ROLE_NAMES`) was dropped after the M1 load. The mapping cannot be rewritten to avoid `principal_role` without restoring the raw data. What the report *can* do is acknowledge the constraint honestly and show the production-correct alternative.

**Proposed fix — two locations in `7_mapping.tex`:**

**1. Add to §7.1 Approach (after line 17), a new paragraph:**
```latex
It should be noted that the mapping relies on the \texttt{principal\_role} table,
which was introduced during Milestone~1 to normalise comma-separated character names
from the original IMDb data. In a production R2RML scenario, the source database is
treated as read-only and schema modifications are not permissible. The correct approach
in that context would be to express the string-split directly inside an
\texttt{rr:sqlQuery}, using a numbers-table technique to produce one row per character
name without altering the schema:

\begin{verbatim}
SELECT tp.TITLE_ID, tp.TALENT_ID, tp.ORD,
  TRIM(SUBSTRING_INDEX(
    SUBSTRING_INDEX(tp.ROLE_NAMES, ',', n.n), ',', -1)) AS ROLE_NAME
FROM title_principal_raw tp
JOIN numbers n
  ON n.n <= 1 + LENGTH(tp.ROLE_NAMES)
               - LENGTH(REPLACE(tp.ROLE_NAMES, ',', ''))
WHERE tp.ROLE_NAMES IS NOT NULL
\end{verbatim}

Within the scope of this project, the normalisation was performed as part of the
Milestone~1 database design and \texttt{principal\_role} is treated as an integral
part of the schema.
```

**2. Replace line 62:**

Current:
```
Character names, which were normalized into the separate \texttt{principal\_role} table
during Milestone~1, are handled by a dedicated triples map targeting the same
participation IRI template.
```
Replace with:
```latex
Character names are drawn from the \texttt{principal\_role} table and mapped by a
dedicated triples map targeting the same participation IRI template, adding
\texttt{ce:characterName} triples without duplicating participation nodes.
```
(The justification is now in §7.1, so no need to repeat it here.)

**Report only — no mapping changes.**

---

### FIX-14 · Add forward reference to deployment and reasoning in §7 (LOW) — `Solved`
**File:** `report/sec/7_mapping.tex` (end of section)

**Professor feedback:** "How are you, or will you be storing the data and support reasoning?"

**Why it is a problem:**
The mapping section describes how triples are generated but says nothing about what happens next — where the KG is stored, how it is queried, and whether reasoning is applied. The professor expects a sentence bridging generation to deployment.

**Proposed addition — new final paragraph in §7:**
```latex
The generated knowledge graph is serialised to Turtle format and loaded into an
Apache Fuseki triplestore for persistent storage and SPARQL querying, as described
in Section~\ref{sec:deployment}. OWL 2 DL reasoning over the ontology is supported
by loading both the ontology and the instance data into the same dataset; a reasoner
such as HermiT can be applied offline to materialise inferred triples before loading,
or queries can rely on SPARQL property paths for traversal that would otherwise
require inference.
```

**Note:** This references `\label{sec:deployment}` which will be created in M4 (§8 Deployment). Add a `\label{sec:mapping}` to the section heading in `7_mapping.tex` at the same time so the cross-reference from FIX-09 also works.

---

## Part 2 — Milestone 4 Work

Status values: `Waitlist` → `Approved` → `Solved`

| Task | Description | Status |
|------|-------------|--------|
| M4-01 | Deploy Fuseki + Brwsr (Linked Data frontend) + load ontology and KG | Solved |
| M4-02-Q1 | Films with genres and runtime, ordered by runtime | Solved |
| M4-02-Q2 | Persons per participation role (aggregate + HAVING) | Solved |
| M4-02-Q3 | Persons who worked together most (subquery + aggregate) | Solved |
| M4-02-Q4 | Actors appearing in 3+ genres (subquery + HAVING) | Solved |
| M4-02-Q5 | Titles with no director credited (negation as failure) | Solved |
| M4-02-Q6 | Bacon number — shortest path between two actors (property paths) | Solved |
| M4-02-Q7 | Wikidata federation — enrich persons with external data (SERVICE) | Solved |
| M4-02-Q8 | Seasons and episodes per series (aggregate) | Solved |
| M4-02-Q9 | Directors who never acted (MINUS) | Solved |
| M4-02-Q10 | Titles sharing genre and language with a target (subquery + joins) | Solved |
| M4-03-A | Non-trivial demonstrator: Bacon number path explorer | Solved |
| M4-03-B | Non-trivial demonstrator: SHACL validation | Solved |
| M4-04 | Report §8 Deployment, §9 SPARQL, §10 Demonstrator | Solved |

---

### M4-01 · Deploy Fuseki + Brwsr — `Solved`

**Files:** `deployment/docker-compose.yml`, `report/sec/8_deployment.tex`

**Architecture:** Two services in one compose file:
- **Fuseki** (`secoresearch/fuseki`, port 3030) — SPARQL triplestore, TDB2 persistent storage
- **Brwsr** (`clariah/brwsr:latest`, port 5000) — Linked Data browser with content negotiation

Brwsr connects to Fuseki via `http://host.docker.internal:3030/cineexplorer/query`. On Linux, `extra_hosts: host.docker.internal:host-gateway` ensures Brwsr can reach the Fuseki container.

**Commands (run from project root):**
```bash
# 1. Start Fuseki + Brwsr
cd deployment && docker compose up -d

# 2. Create the dataset (TDB2 = persistent, query-optimized)
curl -u admin:admin -X POST http://localhost:3030/$/datasets \
  -d "dbName=cineexplorer&dbType=tdb2"

# 3. Load ontology
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @ontology/cineexplorer_ontology.ttl \
  -H "Content-Type: text/turtle"

# 4. Load KG
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @output/cineexplorer_kg.ttl \
  -H "Content-Type: text/turtle"

# 5. Verify triple count
curl -s -G http://localhost:3030/cineexplorer/query \
  --data-urlencode "query=SELECT (COUNT(*) AS ?n) WHERE { ?s ?p ?o }"
```

**Endpoints after startup:**
- SPARQL query: `http://localhost:3030/cineexplorer/query`
- Fuseki admin UI: `http://localhost:3030`
- Brwsr LD browser: `http://localhost:5000`
- Example person: `http://localhost:5000/data/person/nm0000102`

**Verification query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>
SELECT (COUNT(*) AS ?total) WHERE { ?s ?p ?o }
# Expected: ~15,800 (15,495 KG + ~306 ontology triples)
```

**Report text location:** `report/sec/8_deployment.tex` — written. Covers: two-container architecture, Fuseki setup, KG loading, SPARQL endpoint, Brwsr Linked Data browser, named graph strategy.

---

### M4-02-Q1 · Films with genres and runtime — `Waitlist`

**Techniques:** Basic SELECT, JOIN, ORDER BY
**File:** `sparql/q01_films_genres.sparql`

**Question:** What are all films in the dataset, their genres and runtime, ordered from longest to shortest?

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?title ?genre ?runtime
WHERE {
  ?film a ce:Film ;
        ce:workTitle ?title ;
        ce:runtimeMinutes ?runtime ;
        ce:hasGenre ?g .
  ?g ce:genreName ?genre .
}
ORDER BY DESC(?runtime)
```

**Expected result:** ~24 films × their genres. Some films appear multiple times (one row per genre). Longest runtime at top.

---

### M4-02-Q2 · Persons per participation role — `Waitlist`

**Techniques:** Aggregate (COUNT DISTINCT), GROUP BY, HAVING, ORDER BY
**File:** `sparql/q02_roles_count.sparql`

**Question:** How many distinct persons hold each participation role? Show only roles with more than 5 persons.

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?role (COUNT(DISTINCT ?person) AS ?personCount)
WHERE {
  ?par a ce:Participation ;
       ce:participationRole ?role ;
       ce:playedBy ?person .
}
GROUP BY ?role
HAVING (COUNT(DISTINCT ?person) > 5)
ORDER BY DESC(?personCount)
```

**Expected result:** Roles like "actor", "actress", "director", "writer" with counts. "actor"/"actress" will dominate.

---

### M4-02-Q3 · Persons who worked together most — `Waitlist`

**Techniques:** Subquery, aggregate (COUNT DISTINCT), GROUP BY, ORDER BY, LIMIT
**File:** `sparql/q03_worked_together.sparql`

**Question:** Which pairs of persons collaborated on the most titles together? Show top 10.

**Why subquery:** The inner query counts shared titles per pair; the outer query retrieves names. This avoids computing names for all pairs before filtering.

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?name1 ?name2 ?sharedTitles
WHERE {
  {
    SELECT ?p1 ?p2 (COUNT(DISTINCT ?title) AS ?sharedTitles)
    WHERE {
      ?p1 ce:workedFor ?title .
      ?p2 ce:workedFor ?title .
      FILTER(STR(?p1) < STR(?p2))
    }
    GROUP BY ?p1 ?p2
    ORDER BY DESC(?sharedTitles)
    LIMIT 10
  }
  ?p1 ce:personName ?name1 .
  ?p2 ce:personName ?name2 .
}
ORDER BY DESC(?sharedTitles)
```

**Note:** `FILTER(STR(?p1) < STR(?p2))` avoids counting both (A,B) and (B,A).

---

### M4-02-Q4 · Actors in 3+ genres — `Waitlist`

**Techniques:** Subquery, aggregate (COUNT DISTINCT), HAVING, ORDER BY
**File:** `sparql/q04_actors_multi_genre.sparql`

**Question:** Which actors have appeared in titles spanning 3 or more different genres?

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?name (COUNT(DISTINCT ?genre) AS ?genreCount)
WHERE {
  {
    SELECT ?person
    WHERE {
      ?person a ce:Actor .
      ?person ce:actedIn ?title .
      ?title ce:hasGenre ?g .
      ?g ce:genreName ?genre .
    }
    GROUP BY ?person
    HAVING (COUNT(DISTINCT ?genre) >= 3)
  }
  ?person ce:personName ?name .
  ?person ce:actedIn ?title .
  ?title ce:hasGenre ?g .
  ?g ce:genreName ?genre .
}
GROUP BY ?person ?name
ORDER BY DESC(?genreCount)
```

---

### M4-02-Q5 · Titles with no director credited — `Waitlist`

**Techniques:** Negation as failure (FILTER NOT EXISTS)
**File:** `sparql/q05_no_director.sparql`

**Question:** Which films or series have no director credited in the knowledge graph?

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?title ?type
WHERE {
  { ?work a ce:Film . BIND("Film" AS ?type) }
  UNION
  { ?work a ce:Series . BIND("Series" AS ?type) }
  ?work ce:workTitle ?title .
  FILTER NOT EXISTS {
    ?person ce:directed ?work .
  }
}
ORDER BY ?type ?title
```

**Why interesting:** Some titles in the IMDb sample have no director in `title_principal`. This query reveals gaps in the data.

---

### M4-02-Q6 · Bacon number — shortest collaboration path — `Waitlist`

**Techniques:** SPARQL 1.1 property paths (`/`, `+`)
**File:** `sparql/q06_bacon_number.sparql`

**Question:** Which actors in the KG are within 1 or 2 collaboration steps of a given person? Demonstrate the Bacon number concept.

**Approach:** `ce:workedFor` goes from Person to CreativeWork; `ce:employed` goes back from CreativeWork to Person. The path `ce:workedFor/ce:employed` traverses one "hop" (shared title). Repeating it with `+` gives all reachable collaborators.

**Query — Bacon number 1 (direct collaborators):**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT DISTINCT ?collaboratorName
WHERE {
  # Replace with any person IRI from the KG
  BIND(<http://cineexplorer.local/data/person/nm0000102> AS ?source)
  ?source ce:workedFor ?title .
  ?collaborator ce:workedFor ?title .
  FILTER(?collaborator != ?source)
  ?collaborator ce:personName ?collaboratorName .
}
ORDER BY ?collaboratorName
```

**Query — reachable within 2 hops (Bacon number ≤ 2):**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT DISTINCT ?reachableName
WHERE {
  BIND(<http://cineexplorer.local/data/person/nm0000102> AS ?source)
  ?source (ce:workedFor/ce:employed){1,2} ?reachable .
  FILTER(?reachable != ?source)
  ?reachable ce:personName ?reachableName .
}
ORDER BY ?reachableName
```

**Note:** `(ce:workedFor/ce:employed){1,2}` = 1 or 2 hops. Each hop = one shared title. SPARQL property paths do not guarantee the *shortest* path — they find *any* path of that length. For true shortest-path analysis, all reachable nodes at distance 1 then distance 2 must be compared.

---

### M4-02-Q7 · Wikidata federation — `Waitlist`

**Techniques:** Federated query (SERVICE), REGEX/REPLACE for IRI manipulation, OPTIONAL
**File:** `sparql/q07_wikidata_federation.sparql`
**Resolves:** FIX-05 (`sameAsExternal` deferred to M4)

**Question:** For persons in the CineExplorer KG, retrieve their Wikidata entity and birth date from Wikidata using their IMDb identifier (nconst).

**How it works:** Each person IRI has the pattern `http://cineexplorer.local/data/person/nmXXXXXXX`. The `nconst` value (e.g. `nm0000102`) is already embedded in the IRI. Wikidata property P345 stores IMDb person IDs, so we can match without pre-materializing any `sameAsExternal` triples.

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?localName ?nconst ?wikidataItem ?wikidataLabel ?birthDate
WHERE {
  ?person a ce:Person ;
          ce:personName ?localName .
  BIND(REPLACE(STR(?person), "^.*/", "") AS ?nconst)

  SERVICE <https://query.wikidata.org/sparql> {
    ?wikidataItem wdt:P345 ?nconst .
    OPTIONAL {
      ?wikidataItem wdt:P569 ?birthDate .
    }
    OPTIONAL {
      ?wikidataItem rdfs:label ?wikidataLabel .
      FILTER(LANG(?wikidataLabel) = "en")
    }
  }
}
ORDER BY ?localName
LIMIT 20
```

**Note:** The SERVICE call goes to the live Wikidata SPARQL endpoint. Requires internet access from the Fuseki host. Results depend on which `nconst` values exist in Wikidata. Expect ~50–70% match rate for the sample.

---

### M4-02-Q8 · Seasons and episodes per series — `Waitlist`

**Techniques:** Aggregate (COUNT DISTINCT), GROUP BY, ORDER BY
**File:** `sparql/q08_series_seasons.sparql`

**Question:** For each series, how many distinct seasons and total episodes are recorded?

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?seriesTitle
       (COUNT(DISTINCT ?season) AS ?seasonCount)
       (COUNT(DISTINCT ?ep) AS ?episodeCount)
WHERE {
  ?series a ce:Series ;
          ce:workTitle ?seriesTitle ;
          ce:hasEpisode ?ep .
  OPTIONAL { ?ep ce:seasonNumber ?season . }
}
GROUP BY ?series ?seriesTitle
ORDER BY DESC(?episodeCount)
```

---

### M4-02-Q9 · Directors who never acted — `Waitlist`

**Techniques:** MINUS (set subtraction)
**File:** `sparql/q09_director_never_actor.sparql`

**Question:** Which persons have directed at least one title but have never acted in any title?

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?name
WHERE {
  ?person a ce:Director ;
          ce:personName ?name .
  MINUS {
    ?person ce:actedIn ?anyTitle .
  }
}
ORDER BY ?name
```

**Why MINUS over FILTER NOT EXISTS:** MINUS operates on solution sets (whole result rows), while `FILTER NOT EXISTS` operates on variable bindings. For this pattern they produce the same result, but MINUS is semantically cleaner — it reads as "remove persons who have an `actedIn` triple" rather than "filter out persons for whom an `actedIn` triple exists".

---

### M4-02-Q10 · Titles sharing genre and language with a target — `Waitlist`

**Techniques:** Subquery, multiple joins, COUNT DISTINCT, GROUP BY, ORDER BY
**File:** `sparql/q10_similar_titles.sparql`

**Question:** Given a target title, which other titles share at least one genre AND at least one language with it? Rank by number of shared genres.

**Query:**
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?candidateTitle (COUNT(DISTINCT ?sharedGenre) AS ?commonGenres)
WHERE {
  BIND(<http://cineexplorer.local/data/title/tt1707386> AS ?target)

  # Candidate must share at least one genre with target
  ?target ce:hasGenre ?sharedGenre .
  ?candidate ce:hasGenre ?sharedGenre .
  FILTER(?candidate != ?target)
  ?candidate ce:workTitle ?candidateTitle .

  # Candidate must also share at least one language with target (subquery)
  {
    SELECT DISTINCT ?candidate WHERE {
      BIND(<http://cineexplorer.local/data/title/tt1707386> AS ?target)
      ?target ce:language ?lang .
      ?candidate ce:language ?lang .
    }
  }
}
GROUP BY ?candidate ?candidateTitle
ORDER BY DESC(?commonGenres)
```

**Note:** Replace `tt1707386` with any title IRI from the KG. The inner subquery finds candidates that share a language; the outer query filters to those that also share a genre and counts how many genres they share.

---

### M4-03-A · Non-trivial Demonstrator: Bacon Number — `Waitlist`

**File:** `report/sec/10_demonstrator.tex` (first half)

**What it is:** The Six Degrees of Kevin Bacon game applied to the CineExplorer KG. Given two actors, find the shortest collaboration path between them through shared titles. Each "hop" = one shared title. Bacon number = number of hops from a source actor to any other.

**Implementation approach:**
1. Pick a source person (e.g., the most-connected actor in the KG)
2. Use Q6's property path query to find all persons reachable in 1 hop, then 2 hops
3. Show the path: Actor A → Title X → Actor B → Title Y → Actor C
4. Discuss the graph structure: how many persons are reachable at each distance?

**SPARQL for path reconstruction** (find which title connects two actors):
```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?bridgeTitle
WHERE {
  BIND(<http://cineexplorer.local/data/person/PERSON_A> AS ?p1)
  BIND(<http://cineexplorer.local/data/person/PERSON_B> AS ?p2)
  ?p1 ce:workedFor ?bridgeWork .
  ?p2 ce:workedFor ?bridgeWork .
  ?bridgeWork ce:workTitle ?bridgeTitle .
}
```

**Report content:** Explain the Bacon number concept, show the graph traversal approach using property paths, present results for 2–3 example pairs, discuss the connectivity of the KG (how large is the connected component?).

---

### M4-03-B · Non-trivial Demonstrator: SHACL Validation — `Waitlist`

**File:** `sparql/cineexplorer_shapes.ttl`, `report/sec/10_demonstrator.tex` (second half)

**What it is:** SHACL (Shapes Constraint Language) shapes define structural constraints on the KG. Running validation reveals which instances satisfy the shapes and which violate them. This demonstrates OWA vs CWA — violations are not errors but informative gaps.

**Proposed shapes:**
```turtle
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix ce: <http://cineexplorer.local/ontology#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

# Every CreativeWork must have exactly one workTitle
ce:CreativeWorkShape a sh:NodeShape ;
  sh:targetClass ce:CreativeWork ;
  sh:property [
    sh:path ce:workTitle ;
    sh:minCount 1 ;
    sh:maxCount 1 ;
    sh:datatype xsd:string
  ] .

# Every Person must have a personName
ce:PersonShape a sh:NodeShape ;
  sh:targetClass ce:Person ;
  sh:property [
    sh:path ce:personName ;
    sh:minCount 1 ;
    sh:datatype xsd:string
  ] .

# Every Episode must link to exactly one Series
ce:EpisodeShape a sh:NodeShape ;
  sh:targetClass ce:Episode ;
  sh:property [
    sh:path ce:partOfSeries ;
    sh:minCount 1 ;
    sh:maxCount 1 ;
    sh:class ce:Series
  ] .

# Every Participation must link to a Person and a CreativeWork
ce:ParticipationShape a sh:NodeShape ;
  sh:targetClass ce:Participation ;
  sh:property [
    sh:path ce:playedBy ;
    sh:minCount 1 ;
    sh:maxCount 1 ;
    sh:class ce:Person
  ] ;
  sh:property [
    sh:path ce:participatesIn ;
    sh:minCount 1 ;
    sh:maxCount 1 ;
    sh:class ce:CreativeWork
  ] ;
  sh:property [
    sh:path ce:participationRole ;
    sh:minCount 1 ;
    sh:datatype xsd:string
  ] .
```

**Validation tool:** `pyshacl` (Python):
```bash
pip install pyshacl
pyshacl -s sparql/cineexplorer_shapes.ttl \
        -d output/cineexplorer_kg.ttl \
        -f human
```

**Report content:** Explain what SHACL is and how it differs from OWL cardinality axioms (closed-world enforcement vs open-world semantics). Present each shape, run validation, report any violations found, discuss what they mean about the data quality.

---

### M4-04 · Report Sections §8, §9, §10 — `Waitlist`

**Files:** `report/sec/8_deployment.tex`, `report/sec/9_sparql_queries.tex`, `report/sec/10_demonstrator.tex`
**Stubs already created** with correct `\label` values. `main.tex` already includes them.

**§8 Deployment (`\label{sec:deployment}`):**
- Describe the two-container architecture: MySQL (M1/M3) vs Fuseki (M4) — separate docker-compose files, separate purposes
- Explain dataset creation (TDB2), ontology loading, KG loading
- SPARQL endpoint URL, Fuseki web UI
- Mention that both ontology and KG are loaded into the default graph so class/property declarations are visible to SPARQL queries
- Reference `\ref{sec:mapping}` for KG generation

**§9 SPARQL Queries (`\label{sec:sparql}`):**
For each query Q1–Q10:
- One paragraph: the question, why it is interesting, which SPARQL feature it demonstrates
- The SPARQL code block (verbatim or lstlisting)
- A small results table or summary (2–4 representative rows)
- A summary table at the start mapping each query to the required technique it covers

**§10 Non-trivial Demonstrator (`\label{sec:demonstrator}`):**
- §10.1 Bacon Number: concept, query, results for 2–3 example pairs, connectivity analysis
- §10.2 SHACL: what SHACL is, shapes designed, validation results, discussion of violations

---

## Priority Order (M4)

1. M4-01 — Deploy Fuseki (blocker for everything else)
2. M4-02-Q1 through Q10 — test and finalize all queries against live Fuseki
3. M4-03-A (Bacon number) — depends on Q6 working
4. M4-03-B (SHACL) — independent, can be done in parallel
5. M4-04 — write report sections (last, once queries and demos are verified)

---

## Open Questions (to discuss with professor)
- [x] Is `localhost`-based namespace acceptable or do we need to use a real domain? — accepted
- [x] Is SHACL or Wikidata federation preferred as the non-trivial demonstrator? — both implemented (SHACL + Bacon number); Wikidata used in Q7
- [x] Is a video demo required or can we submit SPARQL results as screenshots? — screenshots accepted

---

**Status: archived 2026-05-04 — superseded by `docs/plan.md` (Official IMDb Migration Plan).**

This file records the M2/M3 fix cycle (FIX-01..FIX-14) and the M4 roadmap, all Solved.
Kept for audit purposes; no further edits expected.

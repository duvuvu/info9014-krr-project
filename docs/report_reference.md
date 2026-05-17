# Report Reference — Section → File Cross-Reference

> This document bridges professor feedback (which targets the report PDF) to the actual files
> that need to change (ontology, mapping, TeX source).
>
> **Workflow:** Professor gives feedback → find the report section it targets here →
> read the linked file:line → trace to the corresponding ontology/mapping element.

---

## Report Structure

`report/main.tex` includes sections in this order:

| §  | File | Title |
|----|------|-------|
| 1  | `sec/1_intro.tex` | Introduction |
| 2  | `sec/2_team.tex` | Team |
| 3  | `sec/3_dataset.tex` | Dataset |
| 4  | `sec/4_infor-system.tex` | Information System |
| 5  | `sec/5_sql_implementation.tex` | SQL Implementation *(empty)* |
| 6  | `sec/6_ontology-engineering.tex` | Ontology Engineering |
| 7  | `sec/7_mapping.tex` | Annotating the Information System |
| 8  | `sec/10_conclusion.tex` | Conclusion |
| A  | `sec/A_ai_use.tex` | AI Use |
| B  | `sec/B_conceptual_schema.tex` | Conceptual Schema (appendix) |
| C  | `sec/C_copetency_questions.tex` | Competency Questions (appendix) |

---

## §6 — Ontology Engineering (`sec/6_ontology-engineering.tex`)

### §6.1 Scope (lines 5–11)
**What the report says:** The ontology supports actor connectivity (Bacon number), Wikidata alignment, and KG exploration. Lists: `CreativeWork`, `Person`, `Genre`, language, region, Participation.

**If feedback targets this section → look at:**
- The ontology's class list: `cineexplorer_ontology.ttl:297–400`
- The scope claim about Wikidata alignment: `cineexplorer_ontology.ttl:172–174` (`sameAsExternal`) and the fact it's never populated in mapping → **FIX-06**

---

### §6.2 Concept Organization (lines 12–56)

#### §6.2.1 Classes (lines 25–39)
**What the report says:**
- `CreativeWork` → `Film`, `Series`, `Episode` (disjoint)
- `Person` → subclasses (not disjoint — multiple roles)
- `Participation` reifies the Person-CreativeWork relation; disjoint from CreativeWork/Person/Genre
- `partOfSeries` is functional; Episode has `qualifiedCardinality "1"` on `partOfSeries`

**If feedback targets this → look at:**
- `cineexplorer_ontology.ttl:332–400` (all class declarations + axioms)
- AllDisjointClasses axiom: `cineexplorer_ontology.ttl:396–398`
- Participation cardinality axioms: `cineexplorer_ontology.ttl:376–390`
- `partOfSeries` FunctionalProperty: `cineexplorer_ontology.ttl:145`

#### §6.2.2 Object Properties (lines 41–49)
**What the report says:**
- `workedFor`/`employed` as top pair, role-specific subproperties
- `workedWith` is "traversal-oriented, can be derived, but may also be materialized" → **[FIX-03]** the "may also be materialized" claim will draw criticism
- `sameAsExternal` links to external identifiers — no cardinality stated here

**If feedback targets this → look at:**
- `cineexplorer_ontology.ttl:23–180` (all object properties)
- Report line 47: *"may also be materialized"* → mapping `<#WorkedWith>` at `mapping/cineexplorer_mapping.ttl:745–766` — **FIX-03**
- Report line 49: *"No cardinality restriction is imposed on sameAsExternal"* — actually the ontology has `maxCardinality "1"` on `Person` and `CreativeWork`: `cineexplorer_ontology.ttl:300–304` — inconsistency between report and ontology

#### §6.2.3 Data Properties (lines 51–56)
**What the report says:**
- Language and region are *"literal attributes"* — "keeps the ontology simple and consistent with their descriptive role"
- This is the explicit justification for **FIX-04** being wrong

**If feedback targets this → look at:**
- `cineexplorer_ontology.ttl:234–244` (`ce:language`, `ce:region` as DatatypeProperty)
- `mapping/cineexplorer_mapping.ttl:773–809` (`<#TitleLanguage>`, `<#TitleRegion>`)
- Report line 56: the justification text that will need rewriting after FIX-04

---

### §6.3 OWL Profile (lines 58–69)
**What the report says:** OWL 2 DL (qualified cardinality, functional, inverse, disjointness). HermiT verified. Cardinality under OWA ≠ integrity constraint.

**If feedback targets this → look at:**
- `cineexplorer_ontology.ttl:9` (ontology declaration — no explicit `owl:versionIRI`, no profile annotation)
- The ontology does not declare `owl:imports` or its profile formally — this may draw comment

---

### §6.4 Namespace and Documentation (lines 71–73)
**What the report says:** *"A single namespace is used: `https://example.org/cineexplorer/ontology#`"*

**If feedback targets this → look at:**
- `cineexplorer_ontology.ttl:1` — `@prefix : <https://example.org/cineexplorer/ontology#>`
- `mapping/cineexplorer_mapping.ttl:10` — `@prefix ce: <https://example.org/cineexplorer/ontology#>`
- `mapping/cineexplorer_mapping.ttl:51` (and all other templates) — `https://example.org/cineexplorer/title/...`
- This is **FIX-01**: `example.org` is IANA-reserved

---

### §6.5 Encountered Problems (lines 75–79)
**What the report says:** Only 2 bullet points — directionality of relations, and `min 0` axioms.

**If feedback targets this → look at:**
- This is a pure report writing issue — no corresponding ontology/mapping element
- **FIX-07**: expand to cover Protégé usage, Participation design decision, property sub-hierarchy iteration, OWA caveat
- File to change: `report/sec/6_ontology-engineering.tex:75–79`

---

## §7 — Mapping (`sec/7_mapping.tex`)

### §7.1 Approach (lines 5–17)
**What the report says:** R2RML, W3C recommendation, output to `cineexplorer_kg.ttl`, mapping organized around ontology entities not table structure.

**If feedback targets this → look at:**
- `mapping/cineexplorer_mapping.ttl:1–27` (header + IRI strategy comment)
- `mapping/mapping.properties` (JDBC config)

---

### §7.2 IRI Strategy (lines 19–45)
**What the report says:** IRIs based on IMDb identifiers. Templates listed. Participation IRI is composite (title + person + credit order). No blank nodes for main entities.

**If feedback targets this → look at:**
- `mapping/cineexplorer_mapping.ttl:51` (`title` template)
- `mapping/cineexplorer_mapping.ttl:105` (`person` template)
- `mapping/cineexplorer_mapping.ttl:225` (`genre` template)
- `mapping/cineexplorer_mapping.ttl:418` (`participation` template)
- **FIX-01** applies: all templates use `example.org`
- Report line 27–40: `example.org` appears explicitly — professor will see this

---

### §7.3 Mapping Structure (lines 47–85)

#### Creative works paragraph (lines 51–54)
**What the report says:** Film/Series/Episode SQL logic. `partOfSeries` + season/episode numbers.

**If feedback targets this → look at:**
- `mapping/cineexplorer_mapping.ttl:29–78` (`<#Film>`) — includes **FIX-02** `creativeWorkProperties`
- `mapping/cineexplorer_mapping.ttl:83–131` (`<#Series>`) — same issue
- `mapping/cineexplorer_mapping.ttl:137–198` (`<#Episode>`) — `episodeProperties` **FIX-02**

#### Persons paragraph (lines 56–57)
**What the report says:** `talent` → `ce:Person`, role subclasses from `talent_role`.

**If feedback targets this → look at:**
- `mapping/cineexplorer_mapping.ttl:274–296` (`<#Person>`)
- `mapping/cineexplorer_mapping.ttl:302–375` (role subclass maps)
- `mapping/cineexplorer_mapping.ttl:381–398` (`<#PersonProperties>`) — **FIX-02, FIX-05** — NOT mentioned in report text, which is itself suspicious

#### Participation paragraph (lines 59–62)
**What the report says:** `title_principal` → Participation node. `participationRole` from CATEGORY_NAME. Character names from `principal_role` via same template.

**If feedback targets this → look at:**
- `mapping/cineexplorer_mapping.ttl:404–442` (`<#Participation>`)
- `mapping/cineexplorer_mapping.ttl:465–475` (`<#CharacterName>`)

#### "Additional traversal-oriented properties" paragraph (lines 70–73)
**What the report says:** `workedFor`, `actedIn`, `directed`, etc. are *"redundant from a normalization point of view"* but convenient. `workedWith` is *"useful for Bacon-style path analysis"*.

**If feedback targets this → look at:**
- This is the key paragraph for **FIX-03**: `mapping/cineexplorer_mapping.ttl:745–766` (`<#WorkedWith>`)
- Report line 73 justifies `workedWith` as materialized — exactly what the professor will challenge
- **FIX-07** (Solved): `<#Played>` triple map and `ce:played` property removed — they were redundant with `<#ActedIn>` / `ce:actedIn`

#### Language/region paragraph (lines 75–76)
**What the report says:** *"Rather than introducing standalone resources, the mapping attaches them as descriptive literals"* — explicit justification for the literal choice.

**If feedback targets this → look at:**
- `mapping/cineexplorer_mapping.ttl:773–809` (`<#TitleLanguage>`, `<#TitleRegion>`)
- `cineexplorer_ontology.ttl:234–244` (`ce:language`, `ce:region` as DatatypeProperty)
- **FIX-04**: professor will likely challenge this choice given `Genre` is a proper class

---

## Quick Lookup: Feedback Phrase → Report Section → Files

| Feedback phrase | Report section | Primary file:lines | Fix |
|---|---|---|---|
| "namespace not well-chosen" | §6.4 line 73 | `cineexplorer_ontology.ttl:1`, mapping:10 + all templates | FIX-01 |
| "language/region should be resources" | §6.2.3 line 56, §7.3 line 76 | `ontology.ttl:234–244`, `mapping.ttl:773–809` | FIX-04 |
| "workedWith / O(n²)" | §6.2.2 line 47, §7.3 line 73 | `mapping.ttl:745–766` | FIX-03 |
| "concat literal / 1NF" | §7.3 (persons), §7.3 (creative works) | `mapping.ttl:381–398`, `mapping.ttl:70–73` | FIX-02 |
| "sameAsExternal never populated" | §6.1 line 9, §6.2.2 line 49 | `ontology.ttl:172–174`, mapping (absent) | FIX-06 |
| "Encountered Problems too short" | §6.5 lines 75–79 | `6_ontology-engineering.tex:75–79` | FIX-07 |
| "played redundant / duplicate" | §7.3 line 71 | `mapping.ttl:815–834`, `ontology.ttl:51–57` | FIX-08 |
| "GROUP_CONCAT MySQL-specific" | §7.3 (persons, not mentioned!) | `mapping.ttl:386` | FIX-05 |

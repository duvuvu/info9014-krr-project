# Course Reference — INFO9014 KRR (ULiège, 2025–2026 S2)

> Prof. Christophe Debruyne
> Paths:
> - Lectures: `~/Documents/Obsidian Vault/10_Areas/Master/Courses/INFO9014-1_KRR/Lectures/`
> - Labs: `~/Documents/Obsidian Vault/10_Areas/Master/Courses/INFO9014-1_KRR/Assignments/`

---

## Lectures

### L00 — Course Organization
`L00_course_organization.md`
Grading scheme, tooling overview, syllabus structure.

---

### L01 — Introduction to KRR
`L01_introduction.md`
What is knowledge / representation / reasoning. OWA vs CWA, Unique Name Assumption.
> Relevant to: OWA caveat in cardinality restrictions (ontology design).

---

### L02 — Knowledge Graphs
`L02_knowledge_graphs.md`
Definition of a KG, open vs enterprise KGs, KG construction pipeline.
> Relevant to: project justification in report introduction.

---

### L03 — RDF
`L03_rdf.md`
IRIs, namespaces, Turtle serialization, blank nodes, literals, reification, RDF 1.2.
> Relevant to: IRI design (FIX-01), literal vs IRI choice (FIX-04), reification alternative to Participation.

Key sections:
- §IRIs and Namespaces → motivates HTTP-resolvable IRIs
- §Turtle Serialization → Turtle syntax used in ontology/mapping
- §Reification → contrast with our Participation pattern

---

### L04 — RDFS
`L04_rdfs.md`
`rdfs:subClassOf`, `rdfs:domain`, `rdfs:range`, `rdfs:label`, `rdfs:comment`, RDFS inference rules, well-known vocabularies.
> Relevant to: using rdfs:label in mapping (already done), reusing schema.org/skos.

Key sections:
- §The RDFS Vocabulary → domain/range semantics (important: these are entailments, not constraints)
- §Well-Known Vocabularies to Reuse → schema.org, Dublin Core, FOAF

---

### L05 — SPARQL
`L05_sparql.md`
Full SPARQL 1.1: SELECT/CONSTRUCT/ASK/DESCRIBE, FILTER, UNION, OPTIONAL, aggregates, subqueries, negation (FILTER NOT EXISTS / MINUS), property paths, named graphs, federated queries (SERVICE), SPARQL UPDATE.
> **Directly used in M4 queries.** Must cover: subqueries, federated, property paths, aggregates, negation.

Key sections:
- §6 Aggregates and Subqueries → Q2, Q3, Q4 in plan
- §7 Negation → FILTER NOT EXISTS for Q5, Q9
- §9 Property Paths → `*`, `+`, `/`, `^` syntax → Q6 (Bacon number)
- §11 Federated Queries → SERVICE keyword → Q7 (Wikidata)

---

### L06 — Description Logics
`L06_description_logics.md`
ALC, TBox/ABox, semantics, tableau algorithm, reasoning complexity.
> Relevant to: understanding OWL DL profile; justifying HermiT choice.

---

### L07 — OWL
`L07_owl.md`
OWL 2 profiles (EL, QL, RL, DL), class axioms, complex classes, restrictions, property characteristics, individual axioms.
> **Core lecture for ontology design.** Every design decision in M2 should cite this.

Key sections:
- §4 Class Axioms → `owl:disjointWith`, `owl:AllDisjointClasses`
- §5 Class Descriptions → intersection, union, complement
- §6 OWL DL Restrictions → `owl:someValuesFrom`, `owl:allValuesFrom`, `owl:maxQualifiedCardinality`, `owl:qualifiedCardinality` → used in `Episode` and `Participation`
- §8 Property Characteristics → `owl:FunctionalProperty` (on `partOfSeries`), `owl:SymmetricProperty` (on `workedWith`), `owl:InverseFunctionalProperty`, `owl:TransitiveProperty`
- §11 Reasoning in OWL → HermiT verification; OWA semantics

---

### L08 — R2RML
`L08_kg_generation_r2rml.md`
R2RML spec: TriplesMap, LogicalTable (tableName / sqlQuery), SubjectMap (template / termType), PredicateObjectMap, RefObjectMap, join conditions. Direct Mapping vs R2RML vs RML.
> **Core lecture for M3 mapping.** Every mapping design decision should cite this.

Key sections:
- §R2RML — RDB to RDF Mapping Language → full spec walkthrough
  - `rr:template`, `rr:column`, `rr:termType rr:IRI`, `rr:datatype`, `rr:language`
  - `rr:RefObjectMap` with `rr:joinCondition` (we use template-based joins instead)
  - SQL query in `rr:sqlQuery` vs `rr:tableName`
- §Virtual Knowledge Graphs → contrast with materialized approach we use

---

### L09 — Linked Data
`L09_linked_data.md`
Berners-Lee's 4 principles, IR vs NIR, URI patterns (303 redirect, hash URI, hashrange-14), 5-star model, Linked Open Data cloud.
> **Directly relevant to FIX-01 (namespace) and M4 deployment (Brwsr/Fuseki).**

Key sections:
- §Tim Berners-Lee's Four Principles → HTTP URIs, follow-your-nose, link to other URIs
- §Four URI Patterns for Non-Information Resources:
  - Pattern 1: 303 redirect (IR → NIR)
  - Pattern 2: hash URI (NIR at `doc#fragment`)  ← **our ontology uses this**
  - Pattern 3: hash URI with separate namespace doc
  - Pattern 4: HashRange-14
- §The 5-Star Open Data Model → ★★★★★ requires linked data with external URIs
- §SPARQL Endpoints and VoID → relevant for M4 Fuseki deployment

---

### L10 — Rules
`L10_rules.md`
Horn Logic, SWRL, RIF, Datalog, DL-safe rules.
> Relevant to: `workedWith` derivation rule; could be expressed as a SWRL/Datalog rule.

---

### L11 — SHACL
`L11_shacl.md`
SHACL shapes, target nodes, core constraints, validation reports, SHACL vs SPARQL.
> **Directly used in M4 demonstrator** (SHACL validation option).

Key sections:
- §SHACL Shapes → `sh:NodeShape`, `sh:PropertyShape`
- §Selecting Target Nodes → `sh:targetClass`, `sh:targetSubjectsOf`
- §Core Constraint Components → `sh:minCount`, `sh:maxCount`, `sh:datatype`, `sh:class`, `sh:pattern`
- §Validation Reports → `sh:ValidationReport`, `sh:result`, `sh:resultMessage`

---

### L12 — Metadata and Provenance
`L12_metadata_provenance.md`
PROV-O, DCAT, VoID.
> Relevant to: describing the KG with VoID in M4 (optional but strengthens report).

---

## Labs (EX)

### EX00 — Tools Setup
`EX00_tools_setup.md`
Python rdflib, owlrl, Jena setup.

---

### EX01 — RDF and RDFS
`EX01_rdf_rdfs.md`
RDF/XML ↔ Turtle translation, RDFS analysis, reification exercises.
> Relevant to: understanding Turtle syntax, reification.

---

### EX02 — SPARQL
`EX02_sparql.md`
DBpedia remote queries, local Fuseki, aggregates, advanced queries.
> Relevant to: Q2–Q10 in M4 plan; see how Fuseki is set up in this lab.

---

### EX03 — OWL
`EX03_owl.md`
Pizza ontology, property characteristics, cardinality restrictions, Protégé reasoner, inverse properties, group ontology engineering.
> **Most relevant lab for ontology design.** Directly comparable to CineExplorer ontology.

Key exercises:
- EX03.1 → modeling a domain ontology from scratch (mirrors our M2 process)
- EX03.4 → Protégé + HermiT: running reasoner (we did this for v5 verification)
- EX03.6 → group ontology engineering process (mirrors §6.5 Encountered Problems in report)

---

### EX04 — Description Logics
`EX04_description_logics.md`
Model checking, ABox/TBox, tableau.
> Relevant to: understanding HermiT output, consistency checking.

---

### EX05 — R2RML
`EX05_r2rml.md`
Weather station domain: SubjectMap, PredicateObjectMap, RefObjectMap, named graphs, blank nodes.
> **Most relevant lab for M3 mapping.** Our mapping follows the same patterns.

Key exercises:
- EX05.1 → basic TriplesMap with `rr:template` and `rr:column`
- EX05.4 → `rr:RefObjectMap` with join (contrast with our template-based approach)
- EX05.5 → named graphs (relevant for M4 if we use named graph for ontology)

---

### EX06 — Rules
`EX06_rules.md`
SWRL translation, Protégé rules.
> Relevant to: expressing `workedWith` as a derivable rule (FIX-03 justification).

---

### EX07 — Linked Data Tutorial
`EX07_linked_data_tutorial.md`
Apache Fuseki + Brwsr via Docker; content negotiation; publishing a KG as linked data.
> **Directly used in M4-01 (deployment).** Step-by-step Fuseki + Brwsr setup.

Key points:
- Docker Compose for Fuseki (port 3030) + Brwsr frontend
- Loading a Turtle file into Fuseki
- Content negotiation: browser gets HTML (Brwsr), machines get Turtle/JSON-LD
- Named graphs strategy

---

## Relevance Map: Project Issues → Course Material

| Issue / Task | Primary lecture | Primary lab |
|---|---|---|
| FIX-01 Namespace | L09 (URI patterns §4) | — |
| FIX-02 1NF violation at RDF level | L03 (RDF modeling), L08 (R2RML template vs column) | EX05 |
| FIX-03 workedWith derivable | L05 (property paths), L10 (rules) | EX02, EX06 |
| FIX-04 language/region as resources | L03 (IRIs vs literals), L09 (linked data principles) | EX05 |
| FIX-06 sameAsExternal / Wikidata | L09 (linking to external URIs), L05 (SERVICE) | EX02 |
| FIX-07 Ontology process section | L07 (OWL engineering) | EX03.6 |
| FIX-08 played vs actedIn | L07 (property subhierarchy) | EX03 |
| M4-01 Fuseki deployment | L09, L02 | EX07 |
| M4-02 SPARQL queries | L05 | EX02 |
| M4-03 SHACL demonstrator | L11 | — |
| M4-03 Bacon number | L05 (property paths `+`) | EX02 |

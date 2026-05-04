# CineExplorer — Milestone 4

Status values: `Waitlist` → `Approved` → `Solved`

| Task | Description | Status |
|------|-------------|--------|
| M4-01 | Deploy Fuseki + Brwsr (Linked Data frontend) + load ontology and KG | Solved |
| M4-02-Q1 | Films with genres and runtime, ordered by runtime | Waitlist |
| M4-02-Q2 | Persons per participation role (aggregate + HAVING) | Waitlist |
| M4-02-Q3 | Persons who worked together most (subquery + aggregate) | Waitlist |
| M4-02-Q4 | Actors appearing in 3+ genres (subquery + HAVING) | Waitlist |
| M4-02-Q5 | Titles with no director credited (negation as failure) | Waitlist |
| M4-02-Q6 | Bacon number — shortest path between two actors (property paths) | Waitlist |
| M4-02-Q7 | Wikidata federation — enrich persons with external data (SERVICE) | Waitlist |
| M4-02-Q8 | Seasons and episodes per series (aggregate) | Waitlist |
| M4-02-Q9 | Directors who never acted (MINUS) | Waitlist |
| M4-02-Q10 | Titles sharing genre and language with a target (subquery + joins) | Waitlist |
| M4-03-A | Non-trivial demonstrator: Bacon number path explorer | Waitlist |
| M4-03-B | Non-trivial demonstrator: SHACL validation | Waitlist |
| M4-04 | Report §8 Deployment, §9 SPARQL, §10 Demonstrator | Waitlist |

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
- [ ] Is `localhost`-based namespace acceptable or do we need to use a real domain?
- [ ] Is SHACL or Wikidata federation preferred as the non-trivial demonstrator?
- [ ] Is a video demo required or can we submit SPARQL results as screenshots?

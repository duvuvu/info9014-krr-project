# SPARQL Reference — CineExplorer Q1–Q12

> **Status: GOOD — all M4 queries written, executed, and CSV-exported against the official-IMDb KG**
> Files: `sparql/q01_*.sparql` … `sparql/q10_*.sparql` (+ `q06b_bacon_2hops.sparql`)
> Results: `sparql/results/*.csv`
> Endpoint: `http://localhost:3030/cineexplorer/query` (Apache Fuseki, see `docs/runbook.md`)

This document is the working reference for every SPARQL query in the project. It is paired with §9 of the report; the report contains the same queries plus narrative results, and this file adds explanations geared at readers who are new to SPARQL.

---

## Primer for Non-Specialists

If you already know SPARQL, skip ahead to the catalogue.

### What SPARQL is

SPARQL is the W3C-standard query language for RDF graphs. It plays the same role for RDF that SQL plays for relational databases: it is how you ask questions of the data. A SPARQL query says "find every binding of these variables that makes the following triple patterns true in the graph." The answer is a result table.

### Triple patterns and the WHERE clause

The body of a SPARQL query is a `WHERE { ... }` block containing **triple patterns**: triples in which subjects, predicates, and objects can be replaced by variables (any name starting with `?` or `$`). Example:

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>
SELECT ?title WHERE {
  ?film a ce:Film ;
        ce:workTitle ?title .
}
```

This binds `?film` to anything of type `ce:Film` and `?title` to that thing's `ce:workTitle` value, then returns all `?title` values. The semicolon `;` is shorthand: it repeats the previous subject across the next predicate-object pair, so the example is equivalent to:

```sparql
?film a ce:Film .
?film ce:workTitle ?title .
```

### Prefixes

`PREFIX ce: <http://cineexplorer.local/ontology#>` introduces an abbreviation. `ce:Film` then expands to `<http://cineexplorer.local/ontology#Film>`. Use prefixes for every namespace you reference; otherwise queries are unreadable. This project uses:

- `ce:` — our ontology and data namespaces
- `rdfs:` — RDF Schema (`rdfs:label`, `rdfs:subClassOf`, …)
- `rdf:` — RDF core (`rdf:type` — also writable as `a`)
- `xsd:` — XML Schema datatypes (`xsd:string`, `xsd:gYear`, …)
- `wdt:`, `wd:` — Wikidata, used in the federation query (Q7)
- `sh:` — SHACL, used in the demonstrator shapes file

### Variables, results, ordering

`SELECT` declares which variables appear in the result table. `DISTINCT` removes duplicate rows. `ORDER BY ?x` sorts ascending; `ORDER BY DESC(?x)` sorts descending. `LIMIT n` truncates the result. These work as in SQL.

### Aggregation: COUNT, GROUP BY, HAVING

To count, group, or aggregate, use SPARQL's aggregate functions:

```sparql
SELECT ?role (COUNT(DISTINCT ?person) AS ?personCount)
WHERE { ... }
GROUP BY ?role
HAVING (COUNT(DISTINCT ?person) > 5)
```

`GROUP BY` partitions the result rows; the aggregate function then runs over each partition. `HAVING` filters whole groups (post-aggregation), the way `FILTER` filters individual rows (pre-aggregation). Q2, Q3, Q4, Q8, Q10 all use this pattern.

### Subqueries

A subquery is a `SELECT … WHERE { … }` block nested inside another `WHERE { … }`. The inner query runs first, producing a set of bindings; the outer query joins those bindings with its own patterns. Used in Q3 (rank pairs first, resolve names after), Q4 (filter qualifying actors first, then count their genres), and Q10 (find language-compatible candidates first, then count shared genres).

Subqueries matter when you need to `LIMIT` or `HAVING`-filter at one level and then continue computing at another. Without them, you end up materialising names and labels for every candidate before the aggregate filter runs — wasteful.

### Property paths (SPARQL 1.1)

Property paths let you traverse a chain of properties in one expression:

- `ce:workedFor/ce:employed` — concatenation, two hops in sequence (a person's title's other persons).
- `ce:partOfSeries+` — one or more hops along the same property.
- `(ce:workedFor/ce:employed){1,2}` — between 1 and 2 hops.
- `^ce:directed` — inverse direction (use the same property backwards).

Q6 uses property paths to express the Bacon-number "shared title between two persons" hop.

### OPTIONAL

`OPTIONAL { ... }` runs a sub-pattern; if it has no match, the outer row is still returned, with the optional variables left unbound. Use it for properties that may be missing under the Open World Assumption — birth years, season numbers, English labels in Wikidata. Q7 and Q8 use it.

### MINUS vs FILTER NOT EXISTS

Both express negation, but at different semantic levels:

- `FILTER NOT EXISTS { pattern }` — filters rows for which the pattern would have a matching binding. Operates on individual variable bindings.
- `MINUS { pattern }` — removes whole rows from the outer solution set whose bindings overlap with rows that match the pattern. Operates on solution sets.

In practice they often produce the same result, but `MINUS` reads more naturally when you mean "subtract one set of solutions from another" (Q9), and `FILTER NOT EXISTS` reads more naturally when you mean "filter out rows where this triple exists" (Q5).

### Federation: SERVICE

`SERVICE <https://endpoint/sparql> { ... }` delegates a sub-query to an external SPARQL endpoint. The local engine waits for the remote answer and joins it with local bindings. Q7 uses this to look up CineExplorer persons in Wikidata. Federation requires network access and is subject to the remote endpoint's rate limits and uptime.

### How to run a query

The Fuseki SPARQL endpoint is `http://localhost:3030/cineexplorer/query`. Three ways to run:

1. **Web UI** — open `http://localhost:3030`, pick the `cineexplorer` dataset, paste the query, hit run.
2. **curl** — `curl -G --data-urlencode "query=$(cat sparql/q01_films_genres.sparql)" -H "Accept: text/csv" http://localhost:3030/cineexplorer/query`
3. **SPARQL client library** — e.g., `rdflib` in Python with a remote `SPARQLStore`.

Results in `sparql/results/*.csv` were exported via the Fuseki UI's CSV download.

### How to read the catalogue

Each entry has:

- **Question** — the human-language question being answered.
- **Why we need it** — what role this query plays in the catalogue (rubric coverage, validation, dataset profiling).
- **How it works** — the mechanics: which SPARQL features carry the load, and why.
- **The whole query, line by line** — verbatim source plus a row-by-row explanation.
- **Results** — what running the query against the deployed KG actually produces.
- **Explanation** — interpretation: what the result tells us, what to highlight in the report, and where the OWA caveats apply.

---

## Q1 — Films with Genres and Runtime

### Question
*"What are all films in the dataset, with their genres and runtime, ordered from longest to shortest?"*

The simplest of the ten queries — a basic catalogue listing — and the **smoke test** that the whole stack (database → R2RML mapping → ontology → Fuseki) is wired correctly.

### Why we need it

1. **Sanity check.** If the deployment is broken (Fuseki not loaded, mapping misaligned, ontology IRIs wrong), Q1 catches it before the harder queries run.
2. **Multi-property join demonstration.** Films, runtime, and genres live in three different tables in the source DB (`title`, `title_genre`, `genre`); in the KG they're three different predicates. Q1 shows that the R2RML mapping correctly stitches them back together.
3. **Rubric coverage** — the M4 rubric expects basic `SELECT` / `ORDER BY` queries alongside the more advanced ones. Q1 covers that baseline.

### How it works

A SPARQL query is **graph-pattern matching**: you describe a sub-graph using variables, and the engine returns every binding that makes the pattern true. The pattern here is:

```
              ce:workTitle      → ?title
?film  ───────ce:runtimeMinutes → ?runtime
              ce:hasGenre       → ?g  ──ce:genreName──→ ?genre
```

Each `?film` node must satisfy *all four* outgoing edges. For every match the engine records one row `(?title, ?genre, ?runtime)`. A film with three genres produces three rows (same title, same runtime, three different genres) — that's the standard relational behaviour of a many-to-many join.

`ORDER BY DESC(?runtime)` then sorts those rows from longest to shortest.

### The whole query, line by line

[`sparql/q01_films_genres.sparql`](../sparql/q01_films_genres.sparql):

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

| Line | What it does |
|------|--------------|
| `PREFIX ce: …` | Abbreviates our ontology namespace. |
| `SELECT ?title ?genre ?runtime` | Three columns. `?film` and `?g` are used for joining but not returned. |
| `?film a ce:Film` | `a` = `rdf:type`. Restricts `?film` to instances of `ce:Film` (excludes Series, Episode). |
| `ce:workTitle ?title` | Pulls the human-readable title. |
| `ce:runtimeMinutes ?runtime` | Pulls runtime as `xsd:integer`. |
| `ce:hasGenre ?g` | `?g` is a Genre **node** (an IRI), not a string. The semicolons chain all four predicates onto `?film`. |
| `?g ce:genreName ?genre` | One more hop to get the human-readable genre label. The only triple with a different subject. |
| `ORDER BY DESC(?runtime)` | Numeric sort, longest-first — works because `runtime` is `xsd:integer`. |

The two-step lookup `ce:hasGenre ?g . ?g ce:genreName ?genre` reflects the ontology design: a genre is a first-class entity (`ce:Genre`), not a literal string attached to a film. That decision pays off in Q4 and Q10, where genres are reused as join targets.

### Results

[`sparql/results/q01_films_genres.csv`](../sparql/results/q01_films_genres.csv) — **11,252 rows** spanning **4,120 distinct films**. Top of the list:

| title | genre | runtime |
|-------|-------|---------|
| Gangs of Wasseypur | Action | 321 |
| Gangs of Wasseypur | Comedy | 321 |
| Gangs of Wasseypur | Crime | 321 |
| Zack Snyder's Justice League | Action | 242 |
| Zack Snyder's Justice League | Adventure | 242 |
| Zack Snyder's Justice League | Fantasy | 242 |
| Gone with the Wind | Drama | 238 |
| Gone with the Wind | Romance | 238 |
| Gone with the Wind | War | 238 |

### Explanation

- **One row per (film, genre) pair, not one row per film.** *Gangs of Wasseypur* appears three times because it carries three genre tags. SPARQL has no built-in list-concatenation in a basic `SELECT`; producing one row per film would require `GROUP_CONCAT(?genre)` with a `GROUP BY ?film ?title ?runtime`. The unaggregated form is **more honest about the underlying graph structure** — every row corresponds to exactly one `(film, hasGenre, genre)` triple in the KG.
- **Numeric ordering depends on correct datatype.** If `runtimeMinutes` were mapped as `xsd:string`, `ORDER BY DESC` would sort `"99"` before `"321"` lexicographically. The R2RML mapping declares it `xsd:integer`, which is why the longest-first ordering works.
- **What it validates.** A non-empty Q1 result tells us: Fuseki is up, the dataset is loaded, the `ce:Film` class is populated, the four predicates are present and resolvable, and the genre indirection (`hasGenre → genreName`) is intact. If any of those breaks, every other query breaks too — Q1 is the canary.
- **OWA reminder.** A film *without* a `ce:hasGenre` triple drops out of the result entirely (the `?g` branch fails to match). That's not the same as "the film has no genre"; it just means our KG records none. Wrapping the genre branch in `OPTIONAL` would keep such films.

---

## Q2 — Persons per Participation Role

### Question
*"How many distinct persons hold each participation role? Show only roles with more than 5 persons."*

A frequency profile of who-does-what in the dataset.

### Why we need it

1. **Demonstrates aggregation.** First query that *summarises* the graph rather than listing it — exercises `COUNT(DISTINCT)`, `GROUP BY`, `HAVING`, the three SPARQL features the rubric explicitly asks for.
2. **Profiles the dataset.** Knowing the KG holds 22,705 actors but only 1,825 directors helps interpret every other result. Q3, Q4, Q9 all depend on these proportions.
3. **Validates the `Participation` reification.** Roles aren't strings on `Person` — they're attached to a `ce:Participation` node that mediates `?title ↔ ?person ↔ ?role`. If the mapping for `Participation` is wrong, this query returns nothing.

### How it works

The pattern is small and shallow — three predicates on a single subject:

```
?par ─a─→ ce:Participation
?par ─ce:participationRole→ ?role     (a string: "actor", "director", ...)
?par ─ce:playedBy────────→ ?person   (a Person IRI)
```

Every match yields one row `(?par, ?role, ?person)`. The query then **collapses** those rows: `GROUP BY ?role` partitions by role string; `COUNT(DISTINCT ?person)` reports unique persons per bucket. `HAVING` discards groups whose count is ≤ 5. `ORDER BY DESC` sorts the survivors.

Mental model: **`WHERE` produces a flat row-stream → `GROUP BY` chops it into stacks → aggregates collapse each stack → `HAVING` filters the stacks → `ORDER BY` sorts what's left.**

### The whole query, line by line

[`sparql/q02_roles_count.sparql`](../sparql/q02_roles_count.sparql):

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

| Line | What it does |
|------|--------------|
| `SELECT ?role (COUNT(DISTINCT ?person) AS ?personCount)` | Output columns. `?role` is grouped over; `?personCount` is computed by aggregating `?person`. |
| `?par a ce:Participation` | Restricts `?par` to instances of the reification class. |
| `ce:participationRole ?role` | Pulls the role string. |
| `ce:playedBy ?person` | Pulls the person IRI. |
| `GROUP BY ?role` | Partition rows by role string. |
| `HAVING (COUNT(DISTINCT ?person) > 5)` | Post-aggregation filter: keep only groups with ≥ 6 distinct persons. |
| `ORDER BY DESC(?personCount)` | Sort surviving groups largest-first. |

**Why `DISTINCT` inside `COUNT`?** A person can have many participation rows for the same role. Without `DISTINCT`, the count would inflate to total credits, not unique persons.

**Why `HAVING` instead of `FILTER`?** `FILTER` runs *before* aggregation, on individual rows — it cannot see `COUNT(...)`. `HAVING` runs *after* aggregation, on whole groups, and can reference aggregates. The two are not interchangeable.

### Results

[`sparql/results/q02_roles_count.csv`](../sparql/results/q02_roles_count.csv) — 11 rows:

| role | personCount |
|------|-------------|
| actor | 22,705 |
| writer | 5,383 |
| producer | 4,093 |
| director | 1,825 |
| editor | 1,734 |
| composer | 1,308 |
| production_designer | 1,303 |
| cinematographer | 1,261 |
| casting_director | 1,092 |
| self | 333 |
| archive_footage | 47 |

### Explanation

- **The shape of the data.** Actors dominate at ~22.7k, an order of magnitude above any other role. This reflects how IMDb credits work: a single film accrues dozens of cast credits but only one or two directors, one composer, one editor. The KG faithfully reproduces that skew.
- **`actor` and `actress` collapsed.** In a smaller pre-migration sample they appeared separately. On the official IMDb feed the canonical category is `actor`, so the partition merges. Dataset-driven, not query-driven.
- **`self`** = persons appearing as themselves (talk-show guests, documentary subjects). 333 instances signals the KG includes non-fiction content alongside fiction.
- **`archive_footage` at 47** is just above the `> 5` threshold and confirms `HAVING` is doing its job — without it, the result would include long-tail roles with 1–2 persons each.
- **What this validates downstream.** Every later query that refers to "actors" (Q4, Q9), "directors" (Q5, Q9), or "writers" (Q3, Q9) implicitly relies on the role-string vocabulary listed here. A clean 11-row output is evidence the role strings are normalised.
- **OWA caveat.** `personCount` is "persons we recorded in this role," not "persons who have ever held this role."

---

## Q3 — Persons Who Worked Together Most

### Question
*"Which pairs of persons collaborated on the most titles? Top 10."*

A "frequent collaborators" query — IMDb's *"Frequently Cast Together"* feature in SPARQL.

### Why we need it

1. **Demonstrates a genuine SPARQL subquery.** The subquery does *load-bearing* work — removing it materially changes the query plan.
2. **Demonstrates self-join over a single property.** `?p1 ce:workedFor ?title . ?p2 ce:workedFor ?title .` joins the relation with itself. Pair-discovery queries are graph-shaped problems that SPARQL expresses naturally — every triple is a binary relation.
3. **Stresses the "canonical pair" pattern.** `FILTER(STR(?p1) < STR(?p2))` is the recurring SPARQL idiom for unordered pairs.

### How it works

The naive pattern "find all pairs of people who share a title" is a Cartesian self-join: with 22k actors and titles carrying dozens of credits, intermediate row counts can explode. We tame this in three steps:

1. **Self-join with canonical ordering.** Match `?p1` and `?p2` on the same `?title`, force `STR(?p1) < STR(?p2)` so each unordered pair `{A,B}` appears once (instead of twice — `(A,B)` and `(B,A)` — plus the trivial `(A,A)` self-pairs).
2. **Aggregate inside a subquery.** Group by `(?p1, ?p2)`, count distinct shared titles, sort, `LIMIT 10`. Returns *just 10 pair-IRIs plus their counts*, not the full 22k×22k space.
3. **Resolve names in the outer query.** Once we have only 10 pairs, the `personName` lookup happens 20 times, not 22k×22k times.

This is the classic **"filter / rank → enrich"** subquery pattern; the same shape reappears in Q4 and Q10.

### The whole query, line by line

[`sparql/q03_worked_together.sparql`](../sparql/q03_worked_together.sparql):

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

| Line | What it does |
|------|--------------|
| `SELECT ?name1 ?name2 ?sharedTitles` (outer) | Final result columns. |
| Inner `SELECT ?p1 ?p2 (COUNT(DISTINCT ?title) AS ?sharedTitles)` | Subquery's projection. |
| `?p1 ce:workedFor ?title . ?p2 ce:workedFor ?title .` | Self-join: any two persons attached to the *same* title. |
| `FILTER(STR(?p1) < STR(?p2))` | Canonical ordering — eliminates `(A,A)` self-pairs and `(B,A)` mirrors. |
| `GROUP BY ?p1 ?p2` | One bucket per pair. |
| `COUNT(DISTINCT ?title)` | Counts shared titles. |
| `ORDER BY DESC(?sharedTitles) LIMIT 10` (inside subquery) | Rank pairs by count and keep the top 10. |
| `?p1 ce:personName ?name1 . ?p2 ce:personName ?name2 .` (outer) | After the subquery returns 10 pair-rows, fetch each name. |
| `ORDER BY DESC(?sharedTitles)` (outer) | Re-sort. SPARQL does *not* guarantee result order is preserved across subquery boundaries. |

**The `STR()` cast in `FILTER`.** Comparing IRIs directly with `<` is undefined; cast to string first. Lexicographic order is arbitrary but stable — canonicalisation, not human-meaningful ordering.

### Results

[`sparql/results/q03_worked_together.csv`](../sparql/results/q03_worked_together.csv):

| name1 | name2 | sharedTitles |
|-------|-------|--------------|
| Deborah Aquila | Tricia Wood | 63 |
| Janet Hirshenson | Jane Jenkins | 55 |
| Tim Bevan | Eric Fellner | 52 |
| Mary Vernieu | Lindsay Graham | 46 |
| Amanda Mackey | Cathy Sandrich Gelfond | 45 |
| George R.R. Martin | Ramin Djawadi | 40 |
| Nina Gold | Robert Sterne | 37 |
| Kevin Feige | Sarah Finn | 36 |
| David Benioff | D.B. Weiss | 34 |
| Nina Gold | George R.R. Martin | 32 |

### Explanation

- **The dataset migration changed the answer's character.** On the small *Les Misérables* slice every pair shared one title; on the official IMDb feed the top pair (Deborah Aquila / Tricia Wood, 63 titles) is a real signal. Evidence the migration produces qualitatively different — and more interesting — results.
- **The casting-director cluster.** Seven of the top ten pairs are casting professionals. They typically work in long-running professional partnerships — the densest collaboration sub-graph in IMDb. The query surfaces this without any domain knowledge baked in.
- **Producer pair (Tim Bevan / Eric Fellner)** are the founders of Working Title Films — 52 shared titles is essentially their entire joint filmography.
- **Showrunner duos** — Benioff/Weiss (Game of Thrones) and Martin/Djawadi (also GoT plus *House of the Dragon*) — appear because TV series accrue many episode-level credits per person.
- **Why the subquery is *necessary*, not stylistic.** Without it, the engine would join `personName` for every (p1, p2) candidate before sorting — 22k² candidate pairs ≈ 500M name-lookups. With it, name lookup runs 20 times. Sub-second response vs. time-out.
- **`workedFor` is the union over all role-properties.** Defined in the ontology so that *any* role contributes to "worked together." For "actors who shared a screen," substitute `actedIn`.
- **OWA reminder.** "Shared 63 titles" is a lower bound on actual collaboration.

---

## Q4 — Actors Spanning Three or More Genres

### Question
*"Which actors have appeared in titles spanning at least three different genres?"*

A versatility query — finds actors whose filmography crosses genre boundaries.

### Why we need it

1. **Showcases a *nested* aggregate.** The most pedagogically valuable subquery in the catalogue: it has to aggregate *twice* over the same join — once to filter, once to report.
2. **Demonstrates `HAVING` inside a subquery.** Q2 had `HAVING` at the top level; Q4 pushes it into a subquery, so the *post-aggregation* count becomes a *pre-projection* filter for the outer query.
3. **Stresses transitive-shaped joins.** Genre is two hops away from a person (`person → actedIn → title → hasGenre → g → genreName`). Real KG questions are rarely one-hop.

### How it works

The question has two sub-parts:

1. *"Which actors qualify?"* — group by person, count genres, keep those with count ≥ 3.
2. *"For each qualifying actor, show their name and exact genre count."* — group by person *and* name, with the count as a column.

The subquery is **not strictly required** — `HAVING` could go in a single outer query. The team chose the two-pass form because:

- It separates **selection** (who qualifies) from **reporting** (what to show), matching the SPARQL idiom from Q3.
- The inner pass drops `?title`, `?g`, and `?genre` from its output — the subquery returns just `?person`, a much smaller intermediate result.

### The whole query, line by line

[`sparql/q04_actors_multi_genre.sparql`](../sparql/q04_actors_multi_genre.sparql):

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

| Line | What it does |
|------|--------------|
| **Inner subquery** | |
| `?person a ce:Actor` | Restrict to instances of `ce:Actor`. |
| `?person ce:actedIn ?title` | Hop 1: actor → title. |
| `?title ce:hasGenre ?g` | Hop 2: title → genre node. |
| `?g ce:genreName ?genre` | Hop 3: genre node → genre string. |
| `GROUP BY ?person` | Bucket rows by actor. |
| `HAVING (COUNT(DISTINCT ?genre) >= 3)` | Keep only actors whose distinct-genre count is ≥ 3. |
| `SELECT ?person` | Output is just the IRI — small intermediate result. |
| **Outer query** | |
| `?person ce:personName ?name` | Look up names for qualifying actors. |
| Three join lines | Same pattern as the inner block, repeated to recompute the genre count for the display column. |
| `GROUP BY ?person ?name` | SPARQL requires every non-aggregated SELECT variable to appear in `GROUP BY`. |
| `(COUNT(DISTINCT ?genre) AS ?genreCount)` | Final aggregate — the actual number, not just `≥ 3`. |
| `ORDER BY DESC(?genreCount)` | Most versatile actors first. |

**Why `GROUP BY ?person ?name` instead of just `?person`?** SPARQL groups on **values**, not implicit functional dependencies. Listing `?name` in `GROUP BY` is required to project it.

### Results

[`sparql/results/q04_actors_multi_genre.csv`](../sparql/results/q04_actors_multi_genre.csv) — **17,832 actors** qualify. Top of the ranking:

| name | genreCount |
|------|------------|
| Kirsten Dunst | 19 |
| Christian Bale | 18 |
| Harrison Ford | 18 |
| Amanda Seyfried | 17 |
| Colin Farrell | 17 |
| Ewan McGregor | 17 |

Distribution by `genreCount`:

| genreCount | actors |
|------------|--------|
| 3 | 11,832 |
| 4 | 1,222 |
| 5 | 1,386 |
| 6 | 1,005 |
| 7 | 568 |
| 8 | 484 |
| 9 | 354 |
| 10 | 295 |
| 11 | 221 |
| 12 | 165 |
| 13 | 117 |
| 14 | 92 |
| 15 | 46 |
| 16 | 28 |
| 17 | 14 |
| 18 | 2 |
| 19 | 1 |

### Explanation

- **The migration radically reshaped the answer.** On the small slice every qualifying actor hit the floor (`genreCount = 3`); on the official IMDb feed we get a real long-tail distribution — 11,832 actors at the threshold, 1 outlier at 19.
- **What "19 genres" means.** Kirsten Dunst's filmography on IMDb spans roughly the full IMDb taxonomy (Drama, Comedy, Romance, Thriller, Mystery, Crime, Horror, Sci-Fi, Action, Adventure, Biography, Family, Fantasy, Music, Musical, Sport, History, Animation, War). The query surfaces this without encoding any concept of "versatility."
- **Why two passes really are cheaper.** The outer block re-runs the same three-hop join, so we *do* pay the genre-traversal cost twice. But the inner pass projects only `?person`, and `personName` lookup happens once per qualifying actor (17,832 lookups), not once per `(actor, title, genre)` row (potentially millions).
- **Equivalence with the single-pass form.** `HAVING (COUNT(DISTINCT ?genre) >= 3)` could be moved to the outer query. The two-pass form is preferred for clarity and for narrative parallelism with Q3 and Q10.
- **Above-threshold share.** Q4 returns 17,832; Q2 reports 22,705 actors total. Roughly **78% of all actors in the KG span at least three genres** — a useful soundbite.
- **Threshold choice (`≥ 3`) is arbitrary.** Bumping it to `≥ 5` collapses the result; `≥ 10` shrinks to the genuinely versatile (~1,000). The threshold encodes a value judgement.
- **OWA reminder.** "Acted in genres X, Y, Z" is what the KG records; the actor's real-world filmography may be wider.

---

## Q5 — Titles with No Director Credited

### Question
*"Which films and series have no director recorded in the KG?"*

A data-completeness audit dressed up as a content query.

### Why we need it

1. **Demonstrates negation-as-failure (`FILTER NOT EXISTS`).** The rubric's required negation primitive; Q5 is its canonical use case. (Q9 demonstrates the same idea via the alternative `MINUS` operator — pair them in the report to discuss the difference.)
2. **Demonstrates `UNION`.** Films and Series live under disjoint subclasses of `ce:CreativeWork`, so we need a single query that visits both branches and labels each row with its type.
3. **Demonstrates `BIND` for synthesised columns.** `BIND("Film" AS ?type)` injects a constant into the row to distinguish Film rows from Series rows without joining over the `rdf:type` IRI.
4. **Surfaces a real-world data quality finding.** TV series in IMDb credit directors at the *episode* level — Q5 quantifies that asymmetry directly.

### How it works

Three pieces:

1. **`UNION` branch** — match works that are Films *or* Series, binding a string label per branch.
2. **Title lookup** — runs once on every matched `?work`.
3. **`FILTER NOT EXISTS` block** — for each candidate, the engine asks: *"Does there exist any `?person` such that `?person ce:directed ?work` is true?"* If yes, the row is dropped.

`FILTER NOT EXISTS` is **negation as failure** — the closed-world default at the row level. It does not say "this work has no director in the real world"; it says "the KG contains no `ce:directed` triple pointing at this work." Under OWA that's a *recorded gap*, not a *factual claim*.

### The whole query, line by line

[`sparql/q05_no_director.sparql`](../sparql/q05_no_director.sparql):

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?title ?type
WHERE {
  { ?work a ce:Film .   BIND("Film"   AS ?type) }
  UNION
  { ?work a ce:Series . BIND("Series" AS ?type) }
  ?work ce:workTitle ?title .
  FILTER NOT EXISTS {
    ?person ce:directed ?work .
  }
}
ORDER BY ?type ?title
```

| Line | What it does |
|------|--------------|
| `SELECT ?title ?type` | Two-column output: title and a string discriminator. |
| `{ ?work a ce:Film . BIND("Film" AS ?type) }` | First UNION branch. Synthesises the string `"Film"` into `?type`. |
| `UNION` | Set-union of the two branches. |
| `{ ?work a ce:Series . BIND("Series" AS ?type) }` | Second branch — same structure for Series. |
| `?work ce:workTitle ?title` | Pull the title for whichever `?work` matched. `?work` is **shared across the UNION**. |
| `FILTER NOT EXISTS { ?person ce:directed ?work }` | Negation. `?person` is local to the `NOT EXISTS` block — doesn't escape into the outer scope. |
| `ORDER BY ?type ?title` | Films first, then Series; alphabetical inside each group. |

### Results

[`sparql/results/q05_no_director.csv`](../sparql/results/q05_no_director.csv) — **626 titles**:

| breakdown | count |
|-----------|-------|
| Films without a director | **4** |
| Series without a director | **622** |

The four films: *Breathless*, *Fantasia*, *King Kong*, *The Celebration*.

### Explanation

- **The film/series asymmetry is the headline finding.** 622 of 626 missing-director rows are Series. IMDb attaches `directors` at the **episode** (`tvEpisode`) level, not the series (`tvSeries`) level, because most series have a different director per episode. Our mapping faithfully reproduces this: `ce:directed` triples target Episodes, and Series have no incoming `ce:directed`. The "missing director" is correct under IMDb's modelling.
- **The four anomalous films.** Each warrants a sanity check — these are titles where multiple IMDb entries share the same name; whichever specific `tconst` we ingested may genuinely lack the director field, or it may be a data gap. Listing the four `tconst`s in the report would let the reader cross-check.
- **Why `FILTER NOT EXISTS` and not `MINUS`?** Both produce the same result. The natural-language phrasing here is row-shaped: *"keep this row only if no `directed` triple points at this work."* `MINUS` is preferred when the natural phrasing is set-shaped: *"subtract directors from persons"* (Q9). The two queries together let the report compare the operators side by side.
- **OWA caveat — load-bearing for this query.** "No triple recorded" ≠ "no fact in the world." Reporting Q5 honestly means saying *"the KG records no director for these 626 works,"* not *"these 626 works have no director."* The query is an **information-gap finder**, not a biographical claim.
- **What this validates.** A non-zero Series count tells us the Series ↔ Episode link is correctly modelled. A small non-zero Film count tells us the bulk of films *do* have directors recorded — the mapping fires correctly for the common case. If Q5 returned all films, the mapping would be broken; if it returned zero films, all gaps would be hidden. The current 4/622 split is the expected shape.

---

## Q6 — Bacon Number via Property Paths

### Question
*"Who is reachable from a chosen person within 1 (or 2) collaboration hops?"*

The classic [Six Degrees of Kevin Bacon](https://en.wikipedia.org/wiki/Six_Degrees_of_Kevin_Bacon) puzzle, asked of our KG.

### Why we need it

1. **Demonstrates SPARQL 1.1 property paths.** The rubric's required graph-traversal feature, and the Bacon problem is the textbook example.
2. **Demonstrates the path quantifier `{1,2}`.** Unbounded `+` would be more powerful but blows up; bounded keeps the query tractable.
3. **Demonstrates concatenation `/`.** One Bacon "hop" is `workedFor` (person → title) followed by `employed` (title → other person) — the natural use of `/`.
4. **Sets up the non-trivial demonstrator.** Q6 produces the raw data; the demonstrator section ([`docs/demonstrator_reference.md`](demonstrator_reference.md)) generalises this to a coverage analysis at hops 1, 2, 3.

### How it works

Each Bacon hop has the shape:

```
person ──workedFor──→ title ──employed──→ another person
```

In SPARQL: `ce:workedFor/ce:employed`. Applying it once gives 1-hop neighbours; twice gives 2-hop neighbours. `{1,2}` asks for *either* — the union of 1-hop and 2-hop reach.

Two queries:

- **Q6a (1-hop)** writes the join out longhand: explicit `?title`, no property path. Pedagogically clearer.
- **Q6b (2-hop)** uses the property path. The `?title` is hidden inside the path expression.

Both produce the *same* set when the bound is the same; Q6b just generalises to higher k.

### Query A — direct collaborators (1 hop)

[`sparql/q06_bacon_number.sparql`](../sparql/q06_bacon_number.sparql):

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT DISTINCT ?collaboratorName
WHERE {
  BIND(<http://cineexplorer.local/data/person/nm0000128> AS ?source)
  ?source ce:workedFor ?title .
  ?collaborator ce:workedFor ?title .
  FILTER(?collaborator != ?source)
  ?collaborator ce:personName ?collaboratorName .
}
ORDER BY ?collaboratorName
```

| Line | What it does |
|------|--------------|
| `BIND(<…/nm0000128> AS ?source)` | Russell Crowe. The `BIND` makes the source easy to swap. |
| `?source ce:workedFor ?title` | All titles Crowe has a credit on. |
| `?collaborator ce:workedFor ?title` | Self-join: any other person credited on the same title. |
| `FILTER(?collaborator != ?source)` | Excludes the source from his own neighbourhood. |
| `?collaborator ce:personName ?collaboratorName` | IRI → human name. |
| `SELECT DISTINCT` | Collaborators sharing multiple titles otherwise appear once per shared title. |

### Query B — within 2 hops (property path)

[`sparql/q06b_bacon_2hops.sparql`](../sparql/q06b_bacon_2hops.sparql):

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT DISTINCT ?reachableName
WHERE {
  BIND(<http://cineexplorer.local/data/person/nm0000128> AS ?source)
  ?source (ce:workedFor/ce:employed){1,2} ?reachable .
  FILTER(?reachable != ?source)
  ?reachable ce:personName ?reachableName .
}
ORDER BY ?reachableName
```

| Line | What it does |
|------|--------------|
| `?source (ce:workedFor/ce:employed){1,2} ?reachable` | The whole traversal in one expression: from `?source`, follow `workedFor` then `employed`, do this 1 or 2 times. |
| `FILTER(?reachable != ?source)` | Cycles back to the source are possible; exclude self. |
| `SELECT DISTINCT` | Same person reachable by many paths; collapse. |

**Why `workedFor/employed` and not `workedFor/^workedFor`?** Either works. `employed` is defined as the explicit inverse of `workedFor`, so path expressions read forward-only. Pedagogically clearer; semantically equivalent.

**Why `{1,2}` instead of `+`?** `+` would mean "one or more" — unbounded. On 38k persons that risks producing the entire connected component and timing out. `{1,2}` is the question we're actually asking.

### Results

| query | source | hops | reachable persons | % of dataset |
|-------|--------|------|-------------------|--------------|
| Q6a / Q6 | Russell Crowe | 1 | **558** | 1.47 % |
| Q6b | Russell Crowe | 1–2 | **21,214** | 55.73 % |

[`sparql/results/q06_bacon_number.csv`](../sparql/results/q06_bacon_number.csv), [`sparql/results/q06b_bacon_2hops.csv`](../sparql/results/q06b_bacon_2hops.csv).

The full coverage analysis ([`sparql/results/bacon_coverage.csv`](../sparql/results/bacon_coverage.csv)):

| source | hops | reachable | % of 38,067 persons |
|--------|------|-----------|---------------------|
| Kevin Bacon | 1 | 403 | 1.06 % |
| Kevin Bacon | 2 | 18,155 | 47.69 % |
| Kevin Bacon | 3 | 35,033 | **92.03 %** |
| Russell Crowe | 1 | 558 | 1.47 % |
| Russell Crowe | 2 | 21,214 | 55.73 % |

Kevin Bacon at 3 hops reaches 92% of every person in the KG — the "six degrees" conjecture verified on this slice with **degree 3, not 6**.

### Explanation

- **The migration restored the actual graph-theoretic structure.** On the small slice every person appeared in exactly one title, so 2-hop reach collapsed onto the 1-hop reach. On the official IMDb feed, persons span many titles, the small-world structure emerges, and 2-hop reach jumps from 558 to 21,214 — a 38× expansion.
- **Why two query forms instead of one.** Q6a and Q6b are *equivalent* at the 1-hop level (matching `bacon_coverage.csv` row for Crowe@1 = 558, identical to Q6a's row count). They diverge in expressiveness: Q6a is a flat triple pattern, Q6b is a property-path expression. **Property paths are sugar over self-joins** — the same answer at different abstraction levels.
- **Why pick Russell Crowe as the source?** A pre-query identified him as having one of the densest direct neighbourhoods (558 collaborators). Kevin Bacon himself has fewer 1-hop collaborators (403) but his graph is differently shaped — slightly less dense locally, almost identically dense globally.
- **The 92% small-world finding is the headline.** Tells us the collaboration graph in the KG is **highly connected** — exactly the kind of emergent property that justifies modelling the data as a graph. SQL would express this only via recursive CTEs.
- **The 1/2/3-hop coverage progression** (1% → 48% → 92% from Bacon) — each hop roughly **30–50× expands** reach. Consistent with random-graph theory for graphs with skewed degree distributions (a few high-degree hubs, many low-degree leaves) — exactly what IMDb credit data looks like.
- **Why we stopped at hop 3.** Hop 4+ runs into runtime walls on Fuseki without specialised indexing. Hop 3 already captures 92%, so the marginal gain from hop 4 is small. Empirical, not theoretical.
- **Property paths and reasoning interaction.** `ce:employed` is `owl:inverseOf ce:workedFor`. With OWL reasoning the engine could derive `?title employed ?person` triples automatically; without it we materialise them in the mapping. Materialisation was chosen because Fuseki's default reasoning is RDFS-only.
- **OWA reminder — lower-bound semantics.** Missing edges (gaps in `workedFor`) would underestimate reach. Structural query, not biographical claim.
- **Why Q6 is the bridge to the demonstrator.** The 1-hop and 2-hop queries are nice; the *coverage analysis* (1/2/3 hops, multiple sources, percentage of total) is the non-trivial deliverable. See [`docs/demonstrator_reference.md`](demonstrator_reference.md). Q6 is its query primitive.

---

## Q7 — Wikidata Federation

### Question
*"For a chosen set of CineExplorer persons, retrieve their Wikidata entity, English label, and birth date — by linking IMDb identifiers across endpoints."*

A federated lookup that crosses our local KG with a public one.

### Why we need it

1. **Demonstrates SPARQL `SERVICE` (federation).** The most architecturally interesting query of the ten — the KG isn't an island but a node in the wider Linked Open Data cloud.
2. **Resolves FIX-05 *without* materialising `sameAsExternal`.** `SERVICE` lets us join across endpoints on demand. No pre-computed alignment, no staleness, no scaling problem.
3. **Demonstrates IRI string manipulation (`STR`, `REPLACE`).** The `BIND(REPLACE(STR(?iri), regex, repl) AS ?text)` idiom is a recurring need in real projects.
4. **Demonstrates `OPTIONAL` on remote data.** Wikidata coverage is uneven (some entries lack birth dates, English labels, etc.). `OPTIONAL` ensures partial data doesn't drop rows entirely.
5. **Demonstrates `VALUES`.** Inlining a fixed list of IRIs is the cleanest way to control which subset of our 38k persons we send to a remote endpoint.

### How it works

Our person IRIs are `…/data/person/<nconst>`, where `nconst` is the IMDb identifier (e.g. `nm0000128`). Wikidata stores the same identifier on entities via property `P345 ("IMDb ID")`. The cross-KG join key is the `nconst` *string*.

Three steps:

1. **Pick a small set of persons** with `VALUES`. 38k would time out; 10 fits in a single round-trip.
2. **Extract `nconst` from each local IRI** using `BIND(REPLACE(STR(?person), "^.*/", "") AS ?nconst)` — strips everything up to the last `/`.
3. **Send the `nconst` to Wikidata** inside a `SERVICE` block. Fuseki opens an HTTPS connection to Wikidata's public endpoint, runs the inner pattern remotely, and joins results back with the local `?nconst` binding.

### The whole query, line by line

[`sparql/q07_wikidata_federation.sparql`](../sparql/q07_wikidata_federation.sparql):

```sparql
PREFIX ce:  <http://cineexplorer.local/ontology#>
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?localName ?nconst ?wikidataItem ?wikidataLabel ?birthDate
WHERE {
  VALUES ?person {
    <http://cineexplorer.local/data/person/nm0098842>
    <http://cineexplorer.local/data/person/nm1086543>
    <http://cineexplorer.local/data/person/nm0004266>
    <http://cineexplorer.local/data/person/nm0774744>
    <http://cineexplorer.local/data/person/nm0471014>
    <http://cineexplorer.local/data/person/nm0413168>
    <http://cineexplorer.local/data/person/nm0000128>
    <http://cineexplorer.local/data/person/nm0393799>
    <http://cineexplorer.local/data/person/nm0401076>
    <http://cineexplorer.local/data/person/nm0629933>
  }
  ?person ce:personName ?localName .
  BIND(REPLACE(STR(?person), "^.*/", "") AS ?nconst)

  SERVICE <https://query.wikidata.org/sparql> {
    ?wikidataItem wdt:P345 ?nconst .
    OPTIONAL { ?wikidataItem wdt:P569 ?birthDate . }
    OPTIONAL {
      ?wikidataItem rdfs:label ?wikidataLabel .
      FILTER(LANG(?wikidataLabel) = "en")
    }
  }
}
ORDER BY ?localName
```

| Line / block | What it does |
|--------------|--------------|
| `PREFIX wdt:` | Wikidata namespace for direct property values (`<…/prop/direct/>`). The query never names a specific Wikidata entity in the source text, so the `wd:` (`<…/entity/>`) prefix is not declared — `?wikidataItem` is discovered by the join and returned as a full IRI. |
| `VALUES ?person { ... }` | Inline value clause — binds `?person` to each of the 10 IRIs in turn. |
| `?person ce:personName ?localName` | Local lookup — runs locally. |
| `BIND(REPLACE(STR(?person), "^.*/", "") AS ?nconst)` | Cast IRI to string, strip everything up to last `/`, bind `nm…` substring. |
| `SERVICE <https://query.wikidata.org/sparql> { ... }` | Send the inner block to Wikidata. `?nconst` is **already bound** when the block runs. |
| `?wikidataItem wdt:P345 ?nconst` | On Wikidata: find the entity whose IMDb-ID property equals the value we extracted. |
| `OPTIONAL { ?wikidataItem wdt:P569 ?birthDate }` | Date of birth. Wrapped in `OPTIONAL` because not every entity has it. |
| `OPTIONAL { ... rdfs:label ... FILTER(LANG = "en") }` | English label. Wikidata stores labels as language-tagged literals. |
| `ORDER BY ?localName` | Sort alphabetically by our local name. |

**Why `wdt:P345` and not `wd:P345`?** `wdt:` is the *direct* property — gives the value as an immediate object. `wd:P345` would be the IRI of the property entity itself. For data lookup, always `wdt:`.

**Why `^.*/` as the regex?** The "last slash" idiom: `^.*` is greedy, consumes as much as possible while still letting the trailing `/` match — stops at the *final* `/`. Robust against unexpected IRI structures.

### Results

[`sparql/results/q07_wikidata_federation.csv`](../sparql/results/q07_wikidata_federation.csv) — **9 rows** (one short of the 10 requested):

| localName | nconst | wikidataItem | wikidataLabel | birthDate |
|-----------|--------|--------------|---------------|-----------|
| Alain Boublil | nm0098842 | Q284540 | Alain Boublil | 1941-03-05 |
| Amanda Seyfried | nm1086543 | Q189226 | Amanda Seyfried | 1985-12-03 |
| Anne Hathaway | nm0004266 | Q36301 | Anne Hathaway | 1982-11-12 |
| Claude-Michel Schönberg | nm0774744 | Q712004 | Claude-Michel Schönberg | 1944-07-06 |
| Herbert Kretzmer | nm0471014 | Q5734832 | Herbert Kretzmer | 1925-10-05 |
| Hugh Jackman | nm0413168 | Q129591 | *(empty)* | 1968-10-12 |
| Russell Crowe | nm0000128 | Q129817 | Russell Crowe | 1964-04-07 |
| Tom Hooper | nm0393799 | Q295912 | Tom Hooper | 1972-10-05 |
| William Nicholson | nm0629933 | Q706935 | William Nicholson | 1948-01-12 |

**The missing row** is **`nm0401076` (Victor Hugo)**. Wikidata's entity for the historical author has IMDb ID `nm0401076`, but no row appears in our output — meaning the `SERVICE` block found no match. Plausible causes: the Wikidata entry for Hugo (Q535) does not currently expose `wdt:P345 = "nm0401076"` (his IMDb attribution may live on a different entity), or a transient federation issue at query time.

The **Hugh Jackman** row demonstrates `OPTIONAL` working correctly: Q129591 lacks an English `rdfs:label` *at this query time*, so `?wikidataLabel` is unbound — but the row still appears, with birth date intact.

### Explanation

- **Federation closes FIX-05 elegantly.** The `nconst` substring of our IRIs is already the universal join key; `SERVICE` does live alignment. **No pre-computed alignment beats live alignment** for this kind of stable identifier.
- **The `BIND/REPLACE/STR` chain is the load-bearing trick.** Without it we'd have no way to compose our IRIs with `wdt:P345`, which expects a string. Generalises to any cross-KG join on identifiers embedded in IRIs.
- **Why `VALUES` and not "all persons."** Sending 38,067 person-IDs to Wikidata in one query would (a) hit the public endpoint's 60-second timeout, (b) trigger rate-limiting, and (c) fail with a "query too complex" error. The 10-row block is a *demonstration*; production-scale enrichment would batch (e.g. 50 IRIs at a time) and persist results.
- **Honest result interpretation: 9/10 not 10/10.** Federation results are **not deterministic** the way local queries are. Wikidata edits in real time. The Hugo gap is reported as an observed rate (90% on this run), not papered over. **Feature** of LOD, not flaw — forces us to think about snapshot vs. live join.
- **`OPTIONAL` is doing real work.** Hugh Jackman's empty label illustrates why we wrap it: without `OPTIONAL`, his row would vanish entirely on a missing label.
- **The `OPTIONAL` *inside* `SERVICE` — a subtle point.** SPARQL pushes `OPTIONAL` into the remote endpoint. Wikidata handles it correctly; some endpoints don't. Federation portability is not free.
- **Performance.** A single 10-IRI Q7 run takes ~1.5–3s on a warm Wikidata cache, sometimes 10s+ on a cold start. Two to three orders of magnitude slower than local queries. Sets expectations for any user who tries to scale this.
- **Why `rdfs:label` not `schema:name`.** Wikidata uses `rdfs:label` as the canonical multilingual label property; `schema:name` is sometimes present but less consistently. **Conformance, not preference.**
- **What this validates beyond the rubric.** A successful Q7 confirms three things at once: (1) our IRI design is "Linked Data correct" — the identifier is dereferenceable and joinable; (2) network and proxy config allow outbound HTTPS from Fuseki; (3) `nconst` extraction is unambiguous (no `nm…` collisions in the substring strip).

---

## Q8 — Seasons and Episodes per Series

### Question
*"For each series, how many distinct seasons and total episodes are recorded?"*

A structural summary of the TV-series part of the KG.

### Why we need it

1. **Demonstrates `OPTIONAL` on a partial property.** `ce:seasonNumber` is the canonical "may be missing" property in our ontology. Q8 is the textbook use of `OPTIONAL`: keep the row even when the optional triple is absent.
2. **Demonstrates two `COUNT(DISTINCT)` aggregates in one `SELECT`.** Q2 had one count, Q4 had a count behind a `HAVING`. Q8 shows that aggregates are independent — they come out of the same group.
3. **Validates the Series ↔ Episode ↔ Season hierarchy.** The most multi-part class structure in the ontology. If `ce:hasEpisode` or `ce:seasonNumber` is misaligned, Q8 catches it.
4. **Surfaces another data-completeness story.** Whether season-numbering is consistent, partial, or absent — useful context for any subsequent query.

### How it works

A **two-hop join with a nullable third hop**:

```
?series ──hasEpisode──→ ?ep ──seasonNumber──→ ?season   (optional)
```

Each `(series, episode)` pair produces a row. If the episode has a `seasonNumber`, `?season` binds; otherwise it's left unbound but the row stays.

After `GROUP BY ?series ?seriesTitle`:

- `COUNT(DISTINCT ?ep)` — total episodes (always bound, always counted).
- `COUNT(DISTINCT ?season)` — distinct season numbers. **Unbound `?season` is silently skipped by `COUNT`** — so an episode without a season number contributes 0 to the season count but still 1 to the episode count.

### The whole query, line by line

[`sparql/q08_series_seasons.sparql`](../sparql/q08_series_seasons.sparql):

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

| Line | What it does |
|------|--------------|
| `SELECT ?seriesTitle (COUNT(DISTINCT ?season) AS ?seasonCount) (COUNT(DISTINCT ?ep) AS ?episodeCount)` | Three columns: title, season count, episode count. |
| `?series a ce:Series` | Restrict to the Series subclass. |
| `ce:workTitle ?seriesTitle` | Display name. |
| `ce:hasEpisode ?ep` | Mandatory — series with zero recorded episodes drop out. |
| `OPTIONAL { ?ep ce:seasonNumber ?season }` | Try to pull season number; if absent, keep the row with `?season` unbound. |
| `GROUP BY ?series ?seriesTitle` | Group on IRI and title (SPARQL doesn't infer the functional dependency). |
| `ORDER BY DESC(?episodeCount)` | Most episodes first. |

**Why `COUNT(DISTINCT ?season)` not `COUNT(?season)`?** Episodes within a season produce many rows for that season number; `DISTINCT` collapses to unique seasons.

**Why `COUNT(DISTINCT ?ep)`?** Defensive — episodes are unique by IRI, so `COUNT(?ep)` would also work. Cheap insurance against duplicate `hasEpisode` triples.

### Results

[`sparql/results/q08_series_seasons.csv`](../sparql/results/q08_series_seasons.csv) — **15 series** with at least one recorded episode:

| seriesTitle | seasonCount | episodeCount |
|-------------|-------------|--------------|
| Game of Thrones | 8 | 32 |
| Breaking Bad | 5 | 26 |
| Stranger Things | 5 | 14 |
| Attack on Titan | 3 | 13 |
| Black Mirror | 4 | 13 |
| The Last of Us | 2 | 9 |
| House of the Dragon | 2 | 8 |
| One Piece | 1 | 7 |
| A Knight of the Seven Kingdoms | 1 | 6 |
| Chernobyl | 1 | 3 |
| Better Call Saul | 1 | 2 |
| The Lord of the Rings: The Rings of Power | 1 | 2 |
| Dexter: Resurrection | 1 | 1 |
| Heated Rivalry | 1 | 1 |
| Invincible | 1 | 1 |
| The Mandalorian | 1 | 1 |

### Explanation

- **Episode-level data is sparse by design.** Q2 (Series count) showed many series have no director; the 15 here are series with **any episode at all** ingested. Most series in the IMDb sample have only the top-level `tvSeries` row. Sampling decision, not query limitation.
- **`seasonCount = episodeCount` for short-run series.** *Game of Thrones* (8/32) and *Breaking Bad* (5/26) show realistic ratios. Series at the bottom (`1/1`) are series where exactly one episode was sampled.
- **The `seasonCount = 1` floor is the `OPTIONAL` doing its job.** Without `OPTIONAL`, episodes lacking `seasonNumber` would have caused the entire row to drop. With `OPTIONAL`, episodes are counted even though their seasons are unknown.
- **No `seasonCount = 0`.** Theoretically, a series whose every episode lacks `seasonNumber` would yield zero. None appear — **every sampled episode in our KG carries a season number**, a nice consistency property of the official IMDb feed. (A pre-migration sample had 15 such episodes; the new feed cleaned that up.)
- **`OPTIONAL` vs `LEFT OUTER JOIN`.** Identical mental model. Rows from the left side preserved; right-side bindings may be NULL/unbound.
- **Why two aggregates per row instead of two queries.** SPARQL evaluates aggregates **independently per group**. `COUNT(DISTINCT ?ep)` and `COUNT(DISTINCT ?season)` are computed over the same row-stream, but each only sees its own variable.
- **The query is a template.** Any *(parent, child, child-property)* hierarchy fits the same shape: works for "books and chapters per book" or "albums and tracks per album."
- **OWA reminder.** "Series X has Y episodes" really means "the KG records Y episodes for series X." Real-world answer may be larger.

---

## Q9 — Directors Who Never Acted

### Question
*"Which persons have at least one directing credit but no acting credit?"*

A set-subtraction query over role memberships.

### Why we need it

1. **Demonstrates `MINUS` (set subtraction).** Q5 used `FILTER NOT EXISTS`; Q9 deliberately uses `MINUS` for the same logical task, so the report can compare both operators.
2. **Tests the role-disjointness modelling.** `Actor` and `Director` are **not declared disjoint** — a person can hold both roles, like Clint Eastwood or Ben Affleck. Q9 surfaces the actual partition.
3. **Surfaces a population-level fact.** Q2 shows 1,825 distinct directors in role-string form; Q9 surfaces a related but differently-counted set.

### How it works

Set difference:

```
{ persons typed Director }   MINUS   { persons who have an actedIn triple }
```

- Outer block: bind `?person` to every `ce:Director`, pull name.
- `MINUS` block: every `?person` who has at least one `ce:actedIn` triple.
- `MINUS` removes from the outer solution set any row whose `?person` binding overlaps with the inner. Result: directors with no `actedIn` triple anywhere in the KG.

**`MINUS` works on the *whole row*, not just on `?person`.** Two solution rows are compared by the variables they share. Here only `?person` is shared (because `?anyTitle` is local to the inner block and `?name` is local to the outer), so the comparison reduces to "same person." Good practice: keep `MINUS` blocks narrowly scoped.

### The whole query, line by line

[`sparql/q09_director_never_actor.sparql`](../sparql/q09_director_never_actor.sparql):

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

| Line | What it does |
|------|--------------|
| `?person a ce:Director` | Restrict to Director instances. |
| `ce:personName ?name` | Pull display name. |
| `MINUS { ?person ce:actedIn ?anyTitle . }` | Inner block: persons with at least one `actedIn` triple. `?anyTitle` is a placeholder — its value is never used. |
| (effect of MINUS) | Subtract on shared `?person`. Result: directors with **no** matching `actedIn` row. |
| `ORDER BY ?name` | Alphabetical. |

**Why `?anyTitle` and not just leaving it unbound?** SPARQL requires every triple pattern to have three positions filled. The variable is a placeholder; its name signals "we don't care what this is."

**Why no `DISTINCT`?** The outer block produces one row per person. `MINUS` doesn't introduce duplicates — it only removes rows. Naturally distinct.

### Results

[`sparql/results/q09_director_never_actor.csv`](../sparql/results/q09_director_never_actor.csv) — **3,580 directors** with no acting credit.

First few alphabetically: A.C. Mughil, A.R. Murugadoss, Aakash Kaushik, Aanand L. Rai, …

### Explanation

- **The "directors-only" share — a discrepancy worth discussing.** From Q2: 1,825 distinct persons hold the role string `director`. Yet Q9 returns 3,580 — *more* directors than Q2 reports. Two operationalisations of "director":
  - Q2 counts persons whose `ce:participationRole` literal is exactly `"director"` — the role string in the source IMDb credit row.
  - Q9 counts persons typed `ce:Director` — anyone the ontology classifies as a director, which fires whenever the mapping detects *any* directorial credit (including category strings like `"writer-director"`, episode-level director credits, archival roles, etc.).
  The mapping's class-assignment logic is broader than the literal role match. **A genuine data-modelling point worth flagging in the report.**
- **Why `MINUS` over `FILTER NOT EXISTS`.** Both produce the same answer here. Reasons for `MINUS`:
  - Natural-language phrasing is set-shaped: *"directors **minus** actors."*
  - Pairs with Q5's `FILTER NOT EXISTS` to show both negation forms.
  - `FILTER NOT EXISTS` reads more imperative: *"keep the row only if no `actedIn` triple exists."*
- **`MINUS` semantics caveat.** `MINUS` only subtracts when the two row-sets share at least one variable. If they share *no* variables, `MINUS` is a no-op — non-obvious and a common bug source.
- **OWA reminder — load-bearing.** "No `actedIn` triple in the KG" is **not** "has never acted." A real director-who-never-acted query against IMDb would surface, e.g., Stanley Kubrick (correctly) — but our list of 3,580 will inevitably include directors who *did* act in titles outside our slice.
- **Why this complements Q5.** Q5 audited "works without directors"; Q9 audits "directors without acting credits." Together they triangulate the completeness of the role network. **A KRR project earns its name partly by asking the *KG* what it does and doesn't represent** — Q5 + Q9 are the most direct demonstrations.
- **What this validates.** Non-trivial Q9 count (3,580) tells us:
  - Class membership (`a ce:Director`) is correctly populated.
  - The `actedIn` predicate is correctly populated for *some* persons.
  - The two signals are independent.
  If Q9 returned 0, every director would be auto-typed as actor; if it returned all directors, `actedIn` would be empty. Middle-ground is the expected shape.
- **Natural follow-up.** *"Persons who are both Director and Actor"* — the complement set, expressing multi-role talent: `?person a ce:Director, ce:Actor`. Together with Q9, gives the full Director / Actor partition.

---

## Q10 — Titles Sharing Genre and Language

### Question
*"Given a target title (Les Misérables), which other titles share at least one genre **and** at least one language with it? Rank by number of shared genres."*

A content-based similarity query — the SPARQL skeleton of a "you might also like" recommender.

### Why we need it

1. **Composes multiple required techniques in one query.** Subquery, multi-property join, `COUNT(DISTINCT)`, `GROUP BY`, parameterised target via `BIND`. The catalogue's "putting it all together" piece.
2. **Demonstrates set-intersection on two dimensions.** Q9 was set difference; Q10 is set intersection on *two* axes simultaneously. Natural shape of any similarity query: filter on hard constraints, rank on soft constraints.
3. **Demonstrates parameterisation.** `BIND(<…> AS ?target)` is a pattern: change the IRI, re-run, get a different similarity neighbourhood. Q10 is a **template**, not a fixed report.
4. **Provides a non-trivial use case for subqueries.** Unlike Q3 and Q4 — performance optimisation — here the subquery encodes a **semantic** distinction: language is a hard filter, genre is a ranking dimension.

### How it works

Two coupled conditions:

1. **Hard filter (language):** candidate must share *at least one* language with the target. Binary, no count.
2. **Soft ranking (genre):** candidate must share *at least one* genre, ranked by *how many* are shared. Aggregate.

We can't combine these into one flat aggregate without producing wrong counts. If we joined both and grouped by candidate, the `COUNT(DISTINCT ?sharedGenre)` would be inflated by the number of shared languages (a Cartesian explosion across the two many-to-many relations).

The fix is **"subquery as semantic decomposition"**:

- **Inner subquery:** *"who shares at least one language with the target?"* — returns a deduplicated set of candidate IRIs.
- **Outer query:** join the language-compatible candidates back with the genre-overlap pattern, count shared genres, rank.

The two passes match the natural-language structure: *"first filter by language, then rank by genre overlap."*

### The whole query, line by line

[`sparql/q10_similar_titles.sparql`](../sparql/q10_similar_titles.sparql):

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

| Block | What it does |
|-------|--------------|
| `BIND(<tt1707386> AS ?target)` (outer) | Pin target to *Les Misérables* (2012). |
| `?target ce:hasGenre ?sharedGenre` | Pull each genre node attached to the target. |
| `?candidate ce:hasGenre ?sharedGenre` | Self-join: any other title with the same genre node. |
| `FILTER(?candidate != ?target)` | Don't recommend the target as similar to itself. |
| `?candidate ce:workTitle ?candidateTitle` | Display name. |
| **Inner subquery** | |
| `BIND(<tt1707386> AS ?target)` (inner) | **Repeated** because subquery scope is independent — `?target` from outer is invisible inside. |
| `?target ce:language ?lang` | Each language attached to the target. |
| `?candidate ce:language ?lang` | Candidates that share at least one language. |
| `SELECT DISTINCT ?candidate` | Project just the IRI; collapse duplicates. |
| **Aggregation** | |
| `GROUP BY ?candidate ?candidateTitle` | Group on IRI and title. |
| `(COUNT(DISTINCT ?sharedGenre) AS ?commonGenres)` | Count distinct genre nodes shared with target. |
| `ORDER BY DESC(?commonGenres)` | Most genre-similar first. |

**The `BIND` is repeated in the inner subquery.** **Deliberate, not redundant.** SPARQL subqueries have their own variable scope — a `BIND` in the outer block does not flow into an inner `SELECT`. To use `?target` inside the subquery, we must re-bind it.

**`SELECT DISTINCT ?candidate` in the inner block is load-bearing.** Without `DISTINCT`, a candidate sharing 5 languages with the target would appear 5 times in the inner result, propagating into the outer join and inflating the genre count by ×5.

### Results

[`sparql/results/q10_similar_titles.csv`](../sparql/results/q10_similar_titles.csv) — **2,751 candidates** sharing at least one genre and one language with *Les Misérables*. Distribution by `commonGenres`:

| commonGenres | candidates |
|--------------|------------|
| 3 (all three genres shared) | **6** |
| 2 | 434 |
| 1 | 2,311 |

Top of the ranking — the six titles sharing all three of *History / Musical / Drama*:

| candidateTitle | commonGenres |
|----------------|--------------|
| My Fair Lady | 3 |
| Moulin Rouge! | 3 |
| Kabhi Khushi Kabhie Gham… | 3 |
| The Phantom of the Opera | 3 |
| Rent | 3 |
| Saiyaara | 3 |

### Explanation

- **The migration produced a real similarity neighbourhood.** Pre-migration, every candidate shared exactly one genre — not enough genre data to discriminate. Post-migration: 6 perfect matches, 434 partial, 2,311 single-genre. The query's ranking dimension finally does work.
- **The top six are conceptually correct.** Each is a film whose IMDb genre tags include *Drama* and *Musical*, and most have a *History* element. The query found them by **structural property** (shared genre nodes), not embedded similarity logic. The value of an explicit ontology with reusable genre IRIs.
- **Why the subquery isn't optional here.** Without it, the `language` and `genre` joins multiply, and `commonGenres` equals `genres × languages` per candidate. The subquery isn't a performance trick — it **encodes the semantic difference between filter and ranking**. The query *cannot be flattened* without changing its meaning.
- **Why two `BIND` lines for the same IRI.** Subquery scope. A teaching moment — exactly the kind of subtlety that catches first-time SPARQL writers.
- **Parameterisation.** Replacing the two IRIs gives any title's similarity neighbourhood. Lifting `?target` into a `VALUES` block listing several IRIs would produce a similarity matrix — Future Work.
- **Limitations of this similarity model.**
  - **Cardinality bias:** a title with many genres is more similar to many other titles, simply because it has more matching surfaces. *Les Misérables* (3 genres) is "easy" to match. Robust scoring would normalise (e.g. Jaccard).
  - **Unweighted genres:** sharing *Drama* (the most common tag) counts as much as sharing *Musical* (rarer). IDF-style weighting would surface more meaningful matches.
  - **Language as binary filter:** shared-language *count* is not part of the ranking.
  Each is a query-level extension, not an ontology change — a strength of the design.
- **Why Q10 is the catalogue's closer.** Every other technique earns its keep:
  - Q1's basic `SELECT` shape — for the genre join.
  - Q2/Q4/Q8's aggregation — for the genre count.
  - Q3/Q4's filter-then-enrich subquery — for the language gate.
  - Q5's `FILTER` and `BIND` — for target exclusion and parameterisation.
  Reading Q10 last is reading Q1–Q9 in composition.
- **OWA reminder.** "Shares X genres" means "shares X *recorded* genres in the KG." A title with sparse tagging will under-match; one with maximalist tagging will over-match. The query measures the KG, not the cultural truth — but for a recommender this is the right scope.

---

## Q11 — Materialising `ce:workedWith` via CONSTRUCT

### Question
*"Generate a `ce:workedWith` triple for every pair of persons who participated in the same creative work."*

A graph-building query, not a question — the output is RDF, not a result table.

### Why we need it

1. **Demonstrates the only SPARQL form that builds a graph.** Q1–Q10 are all `SELECT`. Q11 introduces `CONSTRUCT`, which returns triples rather than bindings — a distinct, gradable SPARQL feature.
2. **Encodes a rule that the OWL 2 QL profile cannot express.** The natural axiom *"`workedFor` composed with its inverse implies `workedWith`"* is a **property-chain inclusion** (`workedFor ∘ workedFor⁻ ⊑ workedWith`). Property chains are **not in OWL 2 QL** (they are in OWL 2 RL / EL). SWRL rules are also outside the profile. We chose OWL 2 QL to keep query answering tractable over a large KG (§7 of the report); the price is that we cannot assert this derivation in the TBox. **CONSTRUCT** is the principled, profile-respecting workaround.
3. **Closes a loop the rest of the catalogue opens.** `ce:workedWith` is declared `owl:SymmetricProperty` in the ontology and is used by the demonstrator (Bacon number, [`docs/demonstrator_reference.md`](demonstrator_reference.md)), but no source row carries it. Q11 is *how the property becomes populated*.

### How it works

Two persons `?p1`, `?p2` who share a `?work` are, by definition, collaborators. The query emits one `ce:workedWith` triple per such ordered pair:

1. **Self-join on `workedFor`.** Same shape as Q3 — `?p1 ce:workedFor ?work . ?p2 ce:workedFor ?work .` — but no aggregation.
2. **Drop self-loops.** `FILTER(?p1 != ?p2)` removes the trivial `(A,A)` matches.
3. **Emit both directions.** No `STR(?p1) < STR(?p2)` filter, on purpose. The CONSTRUCT then produces both `A workedWith B` and `B workedWith A`, so the materialised graph is closed under symmetry **without** needing a reasoner pass. Downstream code (e.g. Brwsr's incoming/outgoing rendering, Bacon path queries) can traverse `workedWith` in either direction unconditionally.

### The whole query, line by line

[`sparql/q11_construct_workedwith.sparql`](../sparql/q11_construct_workedwith.sparql):

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

CONSTRUCT {
  ?p1 ce:workedWith ?p2 .
}
WHERE {
  ?p1 ce:workedFor ?work .
  ?p2 ce:workedFor ?work .
  FILTER(?p1 != ?p2)
}
```

| Line | What it does |
|------|--------------|
| `CONSTRUCT { ?p1 ce:workedWith ?p2 . }` | Template: for each binding of `?p1`, `?p2` produced by `WHERE`, emit this triple. |
| `?p1 ce:workedFor ?work . ?p2 ce:workedFor ?work .` | Self-join on shared work (any role contributing to `workedFor`). |
| `FILTER(?p1 != ?p2)` | Exclude self-pairs. |

**Why no `LIMIT`.** A `CONSTRUCT` with `LIMIT` would emit an arbitrary truncated slice of the relation — useless as ground truth. We materialise the full closure (and rely on the file being held outside the KG; see *Results* below).

**Why no `STR(?p1) < STR(?p2)`.** Q3 needs canonical pairs because it *counts* pairs and we want each counted once. Q11 needs both directions, because the result is a graph and downstream consumers expect `workedWith` to be navigable from either endpoint.

### Results

The CONSTRUCT was executed against the deployed Fuseki dataset:

```bash
curl -s -X POST http://localhost:3030/cineexplorer/query \
  -H "Accept: text/turtle" \
  -H "Content-Type: application/sparql-query" \
  --data-binary @sparql/q11_construct_workedwith.sparql \
  -o sparql/results/q11_workedwith.ttl
```

Output: [`sparql/results/q11_workedwith_summary.md`](../sparql/results/q11_workedwith_summary.md).
The raw `.ttl` (87 MB) is **gitignored** — too large for the repository, and trivially regenerated.

| Metric | Value |
|--------|-------|
| Triples generated | **1,679,610** |
| Distinct persons in output | 38,067 |
| Source KG size | 1,611,676 triples |
| Persons with `ce:workedFor` | 38,067 |
| Distinct works | 5,000 |
| Ratio: materialised / source | ≈ 1.04× |

Top-10 persons by collaborator degree (excerpt):

| Person | # collaborators |
|--------|-----------------|
| nm0894611 | 2,037 |
| nm0537892 | 1,794 |
| nm0278168 | 1,421 |
| nm0032597 | 1,303 |
| nm0442090 | 1,287 |

### Explanation

- **The result roughly doubles the dataset.** 1.68M new `workedWith` triples vs. 1.61M source triples. This is the empirical motivation for *on-demand* materialisation rather than persistent storage: persisting `workedWith` would inflate the KG by ~104%, and every R2RML re-run would invalidate it. CONSTRUCT-at-query-time keeps a single source of truth.
- **High-degree persons are casting professionals.** Same population that dominates Q3 — casting agents are attached to hundreds of titles, each with a full principal cast, so they accumulate collaborator edges quadratically.
- **Why this is not "the same as Q3."** Q3 *ranks* collaborators by shared-title count; Q11 *populates* the binary relation. Q3 keeps the multiplicity (63 shared titles); Q11 collapses it (a single `workedWith` triple regardless of whether the pair shared 1 or 63 works). They are complementary — Q3 is analytical, Q11 is inferential.
- **Why this matters for the report.** §7 of the report justifies choosing OWL 2 QL over OWL 2 DL/RL by appealing to query-answering complexity. Q11 is the concrete demonstration that we **understood the trade-off**: the profile gives us tractable conjunctive-query answering at the cost of property chains, and we recovered the lost inference via SPARQL. This is exactly the kind of "profile-aware modelling" KRR lectures emphasise.
- **Operational note.** The query is referenced in the spec as something to *run periodically* (e.g. nightly), keeping the materialised graph in a separate Fuseki named graph. For this submission we run it once and report the size; the demonstrator does **not** depend on the materialised graph existing in the store — the Bacon path query (Q6 and demonstrator) traverses `workedFor` directly.
- **OWA reminder.** A missing `workedWith` triple means *"no shared work is recorded in our KG,"* not *"these two never collaborated."* Two actors of the same era who only worked together on a film outside our 5,000-title sample will not be connected.

---

## Q12 — Pairwise Bacon Distance (ASK + iterated reachability)

### Question
*"What is the Bacon number between two specific persons A and B?"*

A point-to-point distance question, complementing Q6 (single-source reachability at distance 1) and Q6b (at distance ≤ 2).

### Why we need it

1. **Demonstrates `ASK`** — the third principal SPARQL form (alongside `SELECT` in Q1–Q10 and `CONSTRUCT` in Q11). `ASK` returns a single boolean, and is the natural shape for *"does a path exist?"* questions.
2. **Demonstrates the canonical SPARQL workaround for shortest path.** SPARQL 1.1 property paths express *reachability*, not *distance* — there is no built-in shortest-path operator. The point-to-point Bacon distance is therefore computed by **iterating `ASK` with increasing path-length bounds**; the smallest `k` for which the query returns `true` is the distance.
3. **Closes the Bacon family** (Q6 = neighbours, Q6b = 2-hop neighbourhood, Q12 = pairwise distance). Each is a different specialisation of the underlying `workedFor / employed` graph.

### How it works

The path `(ce:workedFor / ce:employed){k,k}` matches **exactly `k` collaboration hops**:

- `ce:workedFor` : Person → CreativeWork
- `ce:employed`  : CreativeWork → Person  *(declared as `owl:inverseOf ce:workedFor` in the ontology)*
- Composition `workedFor / employed` : Person → Person via one shared work — i.e. one Bacon hop.
- Quantifier `{k,k}` (exact length) wraps the hop k times.

To find the Bacon distance from A to B, run the query with `k = 1, 2, 3, …`; the smallest `k` that returns `true` is the answer. If every `k` up to some chosen bound returns `false`, the distance exceeds that bound (or A and B are in disconnected components).

### The whole query, line by line

[`sparql/q12_pairwise_bacon.sparql`](../sparql/q12_pairwise_bacon.sparql):

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

ASK {
  BIND(<http://cineexplorer.local/data/person/nm0000102> AS ?source)
  BIND(<http://cineexplorer.local/data/person/nm0000158> AS ?target)
  ?source (ce:workedFor/ce:employed){1,1} ?target .
  FILTER(?source != ?target)
}
```

| Line | What it does |
|------|--------------|
| `ASK { … }` | Returns `true` iff the pattern has at least one solution. No projection, no result table — just a boolean. |
| `BIND(<…/nm0000102> AS ?source)` | Anchor A = Kevin Bacon. |
| `BIND(<…/nm0000158> AS ?target)` | Anchor B = Tom Hanks. |
| `?source (ce:workedFor/ce:employed){1,1} ?target` | Is there exactly one collaboration hop from A to B? |
| `FILTER(?source != ?target)` | Defensive — avoid declaring A its own collaborator if the engine ever considers a zero-length match. |

**On `{n,m}`.** The exact-length / bounded-length property-path quantifier was in **early SPARQL 1.1 drafts** but was **removed from the final REC**. Apache Jena (and therefore Fuseki) implements it as an **engine extension**. On a strict SPARQL 1.1 endpoint, the same query for `k = 2` would need to be rewritten as an explicit two-fold concatenation:

```sparql
?source (ce:workedFor/ce:employed)/(ce:workedFor/ce:employed) ?target .
```

For `k = 3`, three concatenations, and so on. Our deployment runs on Fuseki, so we use the compact form.

**Driver script.** [`sparql/run_pairwise_bacon.py`](../sparql/run_pairwise_bacon.py) does the `k = 1, 2, 3` iteration for several anchor pairs and writes a summary. This is how the table below was produced.

### Results

[`sparql/results/q12_pairwise_bacon_summary.md`](../sparql/results/q12_pairwise_bacon_summary.md):

| Target | nconst | Bacon distance | k=1 (s) | k=2 (s) | k=3 (s) |
|---|---|---|---|---|---|
| Tom Hanks      | `nm0000158` | **1**   | 0.21 ✓ | —       | —       |
| Paul Newman    | `nm0000056` | **2**   | 0.07 ✗ | 0.09 ✓ | —       |
| Spencer Tracy  | `nm0000075` | **3**   | 0.06 ✗ | 0.16 ✗ | 2.94 ✓ |
| Max Steiner    | `nm0000070` | **3**   | 0.05 ✗ | 0.14 ✗ | 2.32 ✓ |
| Groucho Marx   | `nm0000050` | **> 3** | 0.04 ✗ | 0.12 ✗ | 13.98 ✗ |

✓ = `true`, ✗ = `false`. Times are wall-clock for the single ASK at that `k`.

### Explanation

- **Distance 1 — Bacon and Hanks share *Apollo 13* (1995).** The k=1 query returns `true` in 0.21 s. This is genuine 1-hop collaboration, not a transitive inference.
- **Distance 2 — Paul Newman.** No direct collaboration in the KG, but a single intermediary exists. Total time: 0.07 s + 0.09 s = **0.16 s** to confirm the answer (running k=1 first, then k=2).
- **Distance 3 — Spencer Tracy and Max Steiner.** Both are classical-Hollywood figures (Tracy: 1900–1967; Steiner: 1888–1971) whose careers don't overlap Bacon's. The graph still connects them via 3 hops, but the query takes **2.94 s** (≈30× the k=2 cost) — the combinatorial cost of enumerating 3-hop paths becomes visible.
- **Bacon distance > 3 — Groucho Marx.** Returns `false` at k=3 after **13.98 s** (≈90× the k=2 cost). At this point we are enumerating *all* 3-hop paths from Bacon to confirm none reach Groucho — a much harder computation than finding *one* path (which would short-circuit). For a real Bacon-number tool you would need either (a) a graph-database extension with native shortest-path (`SHORTEST PATH` in property graphs), (b) materialised transitive closure (see Q11 for the pattern), or (c) external graph code (e.g. NetworkX) loading the relevant subgraph and running BFS.
- **The combinatorial growth is the lesson.** Per-query times: 0.05 s → 0.12 s → 14 s as `k` goes 1 → 2 → 3. The join blows up roughly as $(\text{average degree})^k$. This is why our materialisation script for SHACL/demonstrator workloads caps the path-length at 2 (Q6b) and uses *single-source* expansion rather than *pairwise* enumeration.
- **Why ASK and not SELECT.** A SELECT with `LIMIT 1` would also work to detect existence, but it carries baggage: a variable projection, result-row machinery, and (depending on the engine) optimisation differences. `ASK` is the semantically correct primitive — *"is the answer yes or no?"* — and most engines short-circuit on the first witness.
- **Why this is a real KRR observation, not a bug report.** SPARQL is a query language for RDF, not a graph algorithms library. The reachability/distance gap is a deliberate spec choice: shortest-path is in PTIME but its inclusion would complicate the closure of property paths under boolean combination. The standard idiom — iterated ASK — is the price.
- **OWA reminder.** A `false` at k=3 means *"no 3-hop collaboration path is recorded in the KG."* It does not mean *"these two are 4+ hops apart in reality"* (the path may pass through a person/work not in our sample) and it does not mean *"they never collaborated"* (the path may exist via a title outside the 5,000-title slice).

---

## Reading SPARQL — Cheat Sheet

| Construct | Plain English |
|-----------|---------------|
| `?x a :C` | `?x` is of type `:C` (`a` is shorthand for `rdf:type`). |
| `?x :p ?y` | Triple pattern: `?x`'s `:p` value is `?y`. |
| `?x :p1 ?y ; :p2 ?z` | Same subject, two predicates: `?x :p1 ?y . ?x :p2 ?z .` |
| `BIND(<iri> AS ?x)` | Set `?x` to that IRI for the rest of the pattern. |
| `FILTER(condition)` | Remove rows where the condition is false. |
| `FILTER NOT EXISTS { p }` | Remove rows for which pattern `p` would have a binding. |
| `OPTIONAL { p }` | Try to match `p`; if it doesn't, leave its variables unbound but keep the row. |
| `UNION { a } { b }` | Match either pattern; result rows come from whichever branch matches. |
| `MINUS { p }` | Remove rows whose bindings overlap with rows matching `p`. |
| `:p+` | One or more `:p` hops. |
| `:p/:q` | One `:p` hop followed by one `:q` hop (concatenation). |
| `:p{1,2}` | Between 1 and 2 hops along `:p`. |
| `^:p` | Inverse direction (use `:p` backwards). |
| `GROUP BY ?x` | Partition results by `?x`; aggregates run per partition. |
| `HAVING (cond)` | Filter whole groups (post-aggregation). |
| `(COUNT(DISTINCT ?x) AS ?n)` | Aggregate; bind result to `?n`. |
| `SERVICE <ep> { p }` | Send sub-pattern to an external SPARQL endpoint. |
| `STR(?x)` | Cast `?x` to a string (useful with REPLACE / regex). |
| `REPLACE(s, regex, repl)` | Regex replace. |

> **Reminder**: SPARQL is graph-pattern-matching, not row-by-row computation. The same pattern can have many bindings; aggregations collapse them. When a query gives unexpected counts, check whether `DISTINCT` is needed somewhere — duplicate rows from many-to-many joins are the most common source of wrong numbers.
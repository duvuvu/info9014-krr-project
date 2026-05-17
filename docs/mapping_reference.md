# Mapping Reference — CineExplorer R2RML

> **Status: GOOD — all M3 fixes applied**
> File: `mapping/cineexplorer_mapping.ttl`
> Engine: `mapping/r2rml.jar` (or `tools/r2rml/r2rml.jar`)
> Config: `mapping/mapping.properties` — MySQL localhost:3307/imdb, output → `output/cineexplorer_kg.ttl`
> Generated KG: **15,255 triples**, 2,229 subject IRIs (regenerated after fixes)

---

## Known Issues (tracked)

| ID | Severity | Issue | Status |
|----|----------|-------|--------|
| FIX-01 | HIGH | `example.org` in all IRI templates — replaced with `cineexplorer.local` globally | **Solved** |
| FIX-02 | HIGH | `creativeWorkProperties`, `episodeProperties`, `personProperties` removed; `originalTitle`, `endYear` added as separate predicate-object maps | **Solved** |
| FIX-03 | MEDIUM | `<#WorkedWith>` self-join removed; `workedWith` derivable at query time via Participation | **Solved** |
| FIX-04 | MEDIUM | `<#TitleLanguage>` / `<#TitleRegion>` now use `LANGUAGE_ID` / `REGION_ID` (ISO codes) without JOIN | **Solved** |
| FIX-05 | MEDIUM | `GROUP_CONCAT` MySQL-specific — auto-fixed by FIX-02 (map removed) | **Solved** |
| FIX-07 | LOW | `<#Played>` triple map and `ce:played` property removed — redundant with `<#ActedIn>` / `ce:actedIn` | **Solved** |
| FIX-11 | MEDIUM | `rdfs:label` added to `<#Participation>` triple map — produces human-readable labels | **Solved** |

---

## Primer for Non-Specialists

This section explains what R2RML is, what the file in `mapping/` actually contains, and how to read each triple map. Skip ahead if you already know R2RML.

### What R2RML does

**R2RML** (RDB to RDF Mapping Language) is a W3C-recommended language for declaring how a relational database becomes an RDF graph. You write a mapping in Turtle syntax; an R2RML processor reads the mapping, executes the SQL it references, and emits triples.

The data flow:

```
MySQL (imdb)              cineexplorer_mapping.ttl              cineexplorer_kg.ttl
┌────────────┐  reads     ┌─────────────────────┐  emits        ┌──────────────────┐
│   tables   │ ─────────▶ │   triple maps       │ ────────────▶ │  RDF triples     │
│   joins    │  via JDBC  │   (rules)           │  per row      │  (Turtle file)   │
└────────────┘            └─────────────────────┘               └──────────────────┘
                                                                15,255 triples,
                                                                2,229 subject IRIs
```

### What a "triple map" is

A triple map is a rule that says: "Run this SQL query; for each row in the result, generate the following triples." It has up to four parts:

1. **`rr:logicalTable`** — the source. Either a literal table name (`rr:tableName "talent"`) or a custom SQL query (`rr:sqlQuery """ SELECT ... """`). One row in the source = one *batch* of triples.
2. **`rr:subjectMap`** — a rule for building the subject IRI of every triple in that batch. Almost always uses `rr:template` to interpolate a column value into a URL pattern (e.g., `"http://cineexplorer.local/data/title/{TITLE_ID}"` becomes `http://cineexplorer.local/data/title/tt1707386` on a row where `TITLE_ID = 'tt1707386'`). Optionally, `rr:class` adds an `rdf:type` triple.
3. **`rr:predicateObjectMap`** — repeated, one per predicate. Each declares one predicate (e.g., `ce:workTitle`) and one object map. The object map either:
   - extracts a literal from a column (`rr:column "PRIMARY_TITLE"`, optionally with `rr:datatype xsd:string`), or
   - builds an IRI by template (`rr:template "http://cineexplorer.local/data/genre/{GENRE_ID}"`) — used when the object is a resource, not a literal.
4. **(implicit)** — the type triple, if `rr:class` was set on the subject map.

So one triple map executes one SQL query and produces one triple per (row × predicate-object-map). Across all maps in `cineexplorer_mapping.ttl`, the result is the 15,495-triple knowledge graph.

### Concrete example, line by line

The `<#Genre>` map (one of the simplest in the file):

```turtle
<#Genre>
  a rr:TriplesMap ;
  rr:logicalTable [ rr:tableName "genre" ] ;            # source: `genre` table
  rr:subjectMap [
    rr:template "http://cineexplorer.local/data/genre/{GENRE_ID}" ;  # subject IRI
    rr:class ce:Genre                                   # adds rdf:type ce:Genre
  ] ;
  rr:predicateObjectMap [
    rr:predicate ce:genreName ;
    rr:objectMap [ rr:column "GENRE_NAME" ; rr:datatype xsd:string ]
  ] ;
  rr:predicateObjectMap [
    rr:predicate rdfs:label ;
    rr:objectMap [ rr:column "GENRE_NAME" ; rr:language "en" ]
  ] .
```

For a row with `(GENRE_ID="comedy", GENRE_NAME="Comedy")`, this map emits:

```
<.../genre/comedy>  rdf:type      ce:Genre .
<.../genre/comedy>  ce:genreName  "Comedy"^^xsd:string .
<.../genre/comedy>  rdfs:label    "Comedy"@en .
```

Three triples per row, one row per genre, 28 genres ⇒ 84 triples from this map.

### Critical R2RML behaviour: NULL handling (R2RML §10.3)

If **any column** referenced inside an `rr:template` or `rr:column` is NULL in a row, the **entire predicate-object pair is skipped** for that row. The subject IRI is still emitted (assuming the subject's template columns aren't NULL). This means optional fields (e.g., `BIRTH_YEAR` for living persons whose birth year isn't recorded) are simply absent from the KG, which is consistent with the Open World Assumption: missing data is missing data.

This is why FIX-02 mattered: bundling three columns into one `rr:template` (e.g., `"{ORIGINAL_TITLE}/{END_YEAR}/{CONTENT_TYPE_NAME}"`) meant that if *any* of the three was NULL, the whole composite triple disappeared — even when two were present. Splitting into three separate predicate-object maps fixes this — each one is now skipped only when its own column is NULL.

### The two ways to specify a logical table

R2RML accepts two forms for `rr:logicalTable`:

- `rr:tableName "talent"` — the entire table, all rows. Simple.
- `rr:sqlQuery """ SELECT ... FROM ... WHERE ... """` — a custom SQL query. Used when the map needs a JOIN, a filter, or a derived column. An R2RML processor treats the query result as a virtual table.

In our mapping, `<#Genre>` and `<#WorkedFor>` use `rr:tableName`; `<#Film>`, `<#Series>`, `<#Episode>`, all role classes, and the role-specific properties use `rr:sqlQuery` because they need to filter on `CONTENT_TYPE_ID`, `CATEGORY_NAME`, or join with lookup tables.

### Connecting maps without RefObjectMaps — the "matching IRI template" trick

R2RML offers `rr:RefObjectMap` for explicit foreign-key joins between maps. We don't use it. Instead, both sides of a relation use the *same* `rr:template` pattern with the same column. For example:

- `<#Person>` builds person IRIs as `http://cineexplorer.local/data/person/{TALENT_ID}` from the `talent` table.
- `<#Actor>` builds person IRIs as `http://cineexplorer.local/data/person/{TALENT_ID}` from a different SQL query.

Because both maps emit the same IRI for the same talent, all triples about that person merge automatically on the same RDF subject. No formal join is required at the mapping level — the RDF model unifies them by IRI equality.

This works only because every entity type has *one* IRI template across the whole mapping. If the template ever changed, every cross-referencing map would have to update. That trade-off is documented in §7.3 of the report.

### How to read each entry below

Every triple map's entry in the catalogue has:

- **Source** — the SQL query or table name.
- **Subject** — the IRI template and (if any) `rr:class`.
- **Properties generated** — the predicates emitted per row, with the column or sub-template each draws from.
- **Notes** — design context, NULL-safety considerations, why this map exists.

---

## IRI Strategy

```
Title          http://cineexplorer.local/data/title/{TITLE_ID}
Person         http://cineexplorer.local/data/person/{TALENT_ID}
Genre          http://cineexplorer.local/data/genre/{GENRE_ID}
Participation  http://cineexplorer.local/data/participation/{TITLE_ID}/{TALENT_ID}/{ORD}
```

IRI stability: `TITLE_ID` and `TALENT_ID` reuse stable IMDb identifiers (`tconst` / `nconst`).
`ORD` is included in the Participation IRI because the same person can hold more than one credit
on the same title (e.g., director AND actor → two rows, same `TITLE_ID`/`TALENT_ID`, different `ORD`).

Cross-entity links (e.g., `ce:partOfSeries`, `ce:hasGenre`) use matching `rr:template` patterns
on both sides rather than `rr:RefObjectMap`. This avoids join overhead but creates tight coupling
to the IRI template — any template change requires updating all referencing maps.

> **Why IMDb identifiers as IRI keys?** Two reasons:
>
> 1. **Stability** — `tt1707386` and `nm0000128` already exist in the source data, are widely recognised, and are stable across IMDb releases. Inventing surrogate keys (e.g., auto-incremented integers) would break the moment the database is rebuilt.
> 2. **Reusability for federation** — Wikidata stores the same `nconst` values under property P345. Embedding the `nconst` in our IRI lets us extract it at query time and join to Wikidata without any pre-materialised `sameAsExternal` triples (see Q7 in M4).
>
> **Why `ORD` in the Participation IRI?** The primary key of `title_principal` is the triple `(TITLE_ID, TALENT_ID, ORD)`. A person credited as both director and actor on the same film generates two rows with the same `TITLE_ID` and `TALENT_ID` but different `ORD` and `CATEGORY_NAME`. Without `ORD`, the IRI template would collapse both credits into one Participation node, losing the distinction.

---

## Triple Maps Catalogue

> All entries below describe triple maps in `cineexplorer_mapping.ttl`. Each table summarises the source, subject, and emitted triples; the surrounding text explains *why* the map looks that way.

### `<#Film>` — Film entities
| | |
|--|--|
| Source | SQL: `title JOIN content_type` WHERE `CONTENT_TYPE_ID IN (1,2,3,6,8,9)` AND `NOT IN title_episode` |
| Subject | `http://cineexplorer.local/data/title/{TITLE_ID}` — class `ce:Film` |
| Properties generated | `ce:workTitle` (xsd:string), `ce:originalTitle` (xsd:string), `ce:releaseYear` (xsd:gYear), `ce:runtimeMinutes` (xsd:nonNegativeInteger), `ce:isAdult` (xsd:boolean), `rdfs:label` (lang:en) |

Content type is captured by `rdf:type ce:Film`; not repeated as a data property.
`ce:originalTitle` skips the triple (R2RML §10.3) if `ORIGINAL_TITLE` is NULL — does not affect other properties.

> **Why the `IN (1,2,3,6,8,9)` filter and the `NOT IN title_episode` exclusion?** The `content_type` table classifies titles as movie / short / TV-movie / TV-series / TV-mini-series / TV-special / TV-short / video / video-game. The IDs `1,2,3,6,8,9` correspond to non-episodic film-like content. The `NOT IN title_episode` exclusion catches the rare case where an episodic title is mistyped — a row that *should* be an Episode but lacks an explicit type — so it doesn't end up double-classified.

---

### `<#Series>` — Series entities
| | |
|--|--|
| Source | SQL: `title JOIN content_type` WHERE `CONTENT_TYPE_ID IN (4,7)` AND `NOT IN title_episode` |
| Subject | `http://cineexplorer.local/data/title/{TITLE_ID}` — class `ce:Series` |
| Properties generated | Same as Film + `ce:originalTitle` (xsd:string), `ce:endYear` (xsd:gYear), `rdfs:label` |

`ce:endYear` uses `rr:column "END_YEAR"` — NULL-safe, skipped independently if no end year recorded.

> Content type IDs `4` and `7` are TV series and TV mini-series. `endYear` lives only on Series because films and episodes don't have a meaningful end year.

---

### `<#Episode>` — Episode entities
| | |
|--|--|
| Source | SQL: `title JOIN title_episode` WHERE `PARENT_TITLE_ID IS NOT NULL` |
| Subject | `http://cineexplorer.local/data/title/{TITLE_ID}` — class `ce:Episode` |
| Properties generated | `ce:workTitle`, `ce:originalTitle`, `ce:releaseYear`, `ce:runtimeMinutes`, `ce:isAdult`, `ce:seasonNumber`, `ce:episodeNumber`, `ce:partOfSeries` (IRI), `rdfs:label` |

`ce:endYear` is NOT on Episode (domain is `Series` only). `ce:originalTitle` covers the original-title need.

> **Episode classification is structural, not by content_type.** Rather than rely on `content_type`, this map joins `title` with `title_episode`: any title that has a `PARENT_TITLE_ID` is an Episode by definition. This is more robust because the relational schema directly encodes episodic membership; we trust that signal over a possibly miscoded content-type field.
>
> **`ce:partOfSeries` is built by template, not by RefObjectMap.** The object IRI is constructed inside this map as `http://cineexplorer.local/data/title/{PARENT_TITLE_ID}` — the same template `<#Series>` uses, so the two merge on the same series IRI in the output graph.

---

### `<#SeriesHasEpisode>` — Inverse hasEpisode links
| | |
|--|--|
| Source | Table `title_episode` |
| Subject | `http://cineexplorer.local/data/title/{PARENT_TITLE_ID}` |
| Properties generated | `ce:hasEpisode` → `http://cineexplorer.local/data/title/{TITLE_ID}` |

Materializes the inverse direction of `partOfSeries` for query convenience.

> An OWL reasoner running over the ontology could derive `hasEpisode` from `partOfSeries` via the `owl:inverseOf` axiom — but only if reasoning is enabled at query time. Since Fuseki by default does not reason over OWL inverses on every SPARQL query, we materialise the inverse direction in the KG. The cost is small (74 extra triples for 74 episodes); the benefit is that any SPARQL query asking "what episodes does this series have?" works without configuring a reasoner.

---

### `<#Genre>` — Genre entities
| | |
|--|--|
| Source | Table `genre` |
| Subject | `http://cineexplorer.local/data/genre/{GENRE_ID}` — class `ce:Genre` |
| Properties generated | `ce:genreName` (xsd:string), `rdfs:label` (lang:en) |

> Notice the Genre IRI uses `GENRE_ID`, an internal numeric identifier from our schema, because IMDb does not publish stable IRIs for genres themselves. This is the only entity type where we rely on a database-internal key rather than an IMDb identifier. Documented in §7.2 of the report.

---

### `<#TitleHasGenre>` / `<#GenreOfTitle>` — Title ↔ Genre links
| | |
|--|--|
| Source | Table `title_genre` |
| `<#TitleHasGenre>` | Title IRI → `ce:hasGenre` → genre IRI |
| `<#GenreOfTitle>` | Genre IRI → `ce:isGenreOf` → title IRI |

Both directions materialized for traversal. Uses matching `rr:template` patterns (no `rr:RefObjectMap`).

> Two maps over the same table: each row of `title_genre` produces one `hasGenre` triple from the title's perspective and one `isGenreOf` triple from the genre's perspective. We materialise both because, again, Fuseki does not auto-derive `owl:inverseOf` at query time.

---

### `<#Person>` — Person entities
| | |
|--|--|
| Source | Table `talent` |
| Subject | `http://cineexplorer.local/data/person/{TALENT_ID}` — class `ce:Person` |
| Properties generated | `ce:personName` (xsd:string), `ce:birthYear` (xsd:gYear), `ce:deathYear` (xsd:gYear), `rdfs:label` (lang:en) |

`ce:personProperties` removed (FIX-02). Career roles are captured by subclass type assertions.

> All persons in `talent` get classified `ce:Person` here. Their *role* subclasses (Actor, Director, etc.) are added by the next group of maps. Because all those maps share the `{TALENT_ID}` template, the role-typing triples merge on the same person IRI.

---

### `<#Actor>`, `<#Director>`, `<#Writer>`, `<#Composer>`, `<#Editor>` — Role subclass typing
| | |
|--|--|
| Source | SQL: `talent_role JOIN role WHERE ROLE_NAME = ...` |
| Subject | Same person IRI — adds `rdf:type ce:Actor` / `ce:Director` / etc. |

Uses `talent_role` (career profession table), not `title_principal` (per-credit table).
Same IRI template as `<#Person>` — triples merge on the same subject node.

> **Why `talent_role` and not `title_principal`?** `talent_role` records what professions a person *generally* practises (career-level), while `title_principal` records what role they performed *on a specific credit*. Tom Hooper's `talent_role` says "director" and "writer" because those are his careers; his `title_principal` row for *Les Misérables* says he was credited as "director" on that title. The role-class assertions belong to the career level — Tom Hooper *is* a Director, period — so they come from `talent_role`.
>
> **What does merging on the same subject node actually mean?** RDF treats two triples with the same subject IRI as describing the same resource, no matter which map produced them. So `<.../person/nm0393799> rdf:type ce:Person` (from `<#Person>`) and `<.../person/nm0393799> rdf:type ce:Director` (from `<#Director>`) coexist as facts about the same individual. There's no JOIN at the mapping level — the merge happens implicitly because both maps build the same IRI string.

---

### `<#Participation>` — Participation reified nodes
| | |
|--|--|
| Source | SQL: `title_principal JOIN category` |
| Subject | `http://cineexplorer.local/data/participation/{TITLE_ID}/{TALENT_ID}/{ORD}` — class `ce:Participation` |
| Properties generated | `ce:playedBy` (→ person IRI), `ce:participatesIn` (→ title IRI), `ce:participationRole` (CATEGORY_NAME, xsd:string), `ce:participationProperties` (JOB, xsd:string), `rdfs:label` (lang:en) |

`rdfs:label` template: `"{CATEGORY_NAME} of {TALENT_ID} in {TITLE_ID}"` — produces labels like `"actor of nm0000128 in tt0000001"@en` (FIX-11).

> **The Participation node is the most subtle part of the mapping.** Each row of `title_principal` represents one credit (one person, one title, one credit-order). The map mints a fresh node IRI from the three-column composite key, types it `ce:Participation`, and attaches:
>
> - `ce:playedBy` → the person IRI (built with the same `{TALENT_ID}` template the `<#Person>` map uses, so they merge);
> - `ce:participatesIn` → the title IRI (similarly merged with `<#Film>` / `<#Series>` / `<#Episode>`);
> - the textual category and free-text job, plus a synthesised label.
>
> The label format was added in FIX-11 because, before, a Participation node had no human-readable identifier. In Brwsr or in SPARQL result tables, labels like `"director of nm0393799 in tt1707386"@en` are far easier to read than the raw IRI.

---

### `<#PersonHasRole>` — Inverse hasRole links
| | |
|--|--|
| Source | Table `title_principal` |
| Subject | Person IRI → `ce:hasRole` → Participation IRI |

Materializes the inverse of `playedBy` for traversal from Person to their Participations.

> Without this, going from a person to their credits would require a backwards traversal in SPARQL: `?par ce:playedBy ?person` instead of `?person ce:hasRole ?par`. Both work; the materialised forward direction is just more readable.

---

### `<#CharacterName>` — Character names on Participation
| | |
|--|--|
| Source | Table `principal_role` (1NF-normalized, one row per character name) |
| Subject | Same Participation IRI |
| Properties generated | `ce:characterName` (ROLE_NAME, xsd:string) |

One Participation IRI can have multiple `ce:characterName` triples (one per character).
`principal_role` was created during M1 to normalize comma-separated character names from the original IMDb data.
In a production R2RML scenario (read-only source), the split would be done via a numbers-table SQL technique inside an `rr:sqlQuery`.

> **Why a separate map and not a column inside `<#Participation>`?** Because one credit can have multiple character names ("Inspector Javert / Bishop"), there is a one-to-many relation between participation and character name. R2RML can produce multiple triples for the same subject only if the source table has multiple rows per subject — which is exactly the shape of `principal_role` after the M1 1NF normalisation. The shared IRI template ensures the `characterName` triples attach to the same Participation node `<#Participation>` already minted.

---

### `<#KnownFor>` — "Known for" links
| | |
|--|--|
| Source | Table `talent_title` |
| Subject | Person IRI → `ce:knownFor` → title IRI |

> The IMDb dataset records, for each person, a small set of titles they are *especially* associated with. The semantic of `knownFor` differs from `actedIn` / `directed` — it is editorial / popularity-driven rather than a structural credit. We map it as a separate property to preserve that distinction.

---

### `<#WorkedFor>` / `<#Employed>` — Generic Person ↔ Work links
| | |
|--|--|
| Source | Table `title_principal` |
| `<#WorkedFor>` | Person IRI → `ce:workedFor` → title IRI |
| `<#Employed>` | Title IRI → `ce:employed` → person IRI |

Both directions materialized. Most general traversal properties.

> These are the most general Person↔Work properties — they fire for *every* row in `title_principal`, regardless of role. The Bacon-number queries in M4 use these because they don't care whether someone was an actor, a writer, or a composer, only that they shared a credit.

---

### `<#ActedIn>` / `<#HasActor>` — Actor ↔ Work (direct link)
| | |
|--|--|
| Source | SQL: `title_principal JOIN category WHERE CATEGORY_NAME IN ('actor','actress')` |
| `<#ActedIn>` | Person IRI → `ce:actedIn` → title IRI |
| `<#HasActor>` | Title IRI → `ce:hasActor` → person IRI |

> Filtered version of `<#WorkedFor>` — same source, but only the rows where the credit category is acting. Generates the role-specific properties declared as sub-properties of `workedFor` in the ontology. The same row in `title_principal` thus contributes triples to *three* maps: `<#WorkedFor>`, `<#Participation>`, and `<#ActedIn>` (when the category is acting). All triples merge on shared IRIs.

---

### `<#Directed>` / `<#DirectedBy>` — Director ↔ Work
Filtered on `CATEGORY_NAME = 'director'`.

---

### `<#Wrote>` / `<#WrittenBy>` — Writer ↔ Work
Filtered on `CATEGORY_NAME = 'writer'`.

---

### `<#Edited>` / `<#EditedBy>` — Editor ↔ Work
Filtered on `CATEGORY_NAME = 'editor'`.

---

### `<#ComposedFor>` / `<#ComposedBy>` — Composer ↔ Work
Filtered on `CATEGORY_NAME = 'composer'`.

> The four pairs above all follow the same template: filter `title_principal` to the relevant `CATEGORY_NAME`, generate the forward direction (Person → Work), generate the inverse direction (Work → Person). Each pair contributes the role-specific predicates declared in the ontology as sub-properties of `workedFor` / `employed`.

---

### `<#TitleLanguage>` / `<#TitleRegion>` — Language and Region (FIX-04)
| | |
|--|--|
| Source | SQL: `title_aka WHERE LANGUAGE_ID / REGION_ID IS NOT NULL` (no JOIN) |
| `<#TitleLanguage>` | Title IRI → `ce:language` (`LANGUAGE_ID`, xsd:string — ISO code) |
| `<#TitleRegion>` | Title IRI → `ce:region` (`REGION_ID`, xsd:string — ISO code) |

Uses ISO codes directly from `title_aka` without joining to `language`/`region` lookup tables.

> Before FIX-04, these maps joined `title_aka` to the `language` / `region` lookup tables to fetch a human-readable name (`'English'`, `'United States'`). After the fix, they use the ISO codes directly (`'en'`, `'US'`) — interoperable with external vocabularies and one fewer JOIN. The professor's M2 feedback ("why model languages as classes when language tags suffice?") confirmed the simpler approach.
>
> **Note**: `ce:language` and `ce:region` are *data properties* (literal values), not object properties. The codes are stored as `xsd:string` literals, not as IRIs to language resources.

---

### Removed triple maps (post-fix)

| Map | Reason |
|-----|--------|
| `<#PersonProperties>` | FIX-02: GROUP_CONCAT 1NF violation; career roles captured by subclass typing |
| `<#WorkedWith>` | FIX-03: O(n²) self-join, symmetric property; derivable via Participation at query time |
| `<#Played>` | FIX-07: identical SQL/subject/object to `<#ActedIn>` — only predicate differed; `ce:played` also removed from ontology |

> **`<#PersonProperties>`** previously concatenated all of a person's role names into a single string literal (e.g., `"director,writer,actor"`) using `GROUP_CONCAT` — a denormalised, MySQL-specific anti-pattern. It also re-introduced a 1NF violation at the RDF level (a multi-valued attribute jammed into one literal). FIX-02 deleted this map and replaced it with subclass typing via `<#Actor>`, `<#Director>`, etc.
>
> **`<#WorkedWith>`** previously self-joined `title_principal` to itself to materialise pairs of co-workers. This generates O(n²) triples per title (10 co-workers ⇒ 90 directed-pair triples, plus the symmetric reverses). It is far cheaper to recompute the relation in SPARQL via a Participation join when a query actually needs it.
>
> **`<#Played>`** ran the same SQL as `<#ActedIn>` (actor/actress rows from `title_principal`) and emitted Person→Work IRIs under a different predicate (`ce:played` vs. `ce:actedIn`). The ontology marked both as `rdfs:subPropertyOf :workedFor` with identical domain (`Actor`) and range (`CreativeWork`), so the two predicates were semantically interchangeable. FIX-07 removed the map and the property; the 240 redundant triples are gone (KG: 15,495 → 15,255).

---

## Run Command

```bash
cd mapping && java -jar r2rml.jar mapping.properties
```

Output: `../output/cineexplorer_kg.ttl`

> **What the command does, step by step:**
>
> 1. Reads `mapping.properties` to find the JDBC connection details, the mapping file path, and the output file path.
> 2. Connects to MySQL (port 3307, db `imdb`, user `imdb_user`).
> 3. Parses `cineexplorer_mapping.ttl`.
> 4. For each triple map: executes the logical-table SQL, iterates rows, applies templates and column extractions, writes triples to the output file.
> 5. Closes the file. Triples are now in `output/cineexplorer_kg.ttl` in Turtle format.
>
> **Common reasons it fails:**
> - MySQL container is not running (`docker compose up -d` from `database/`).
> - The mapping file uses a column or table name that doesn't exist in the schema (typo or schema drift).
> - A column is referenced in `rr:template` with the wrong case — column names are case-sensitive in the mapping but not in MySQL by default; mismatches usually surface as silent NULL substitutions, not errors.

---

## Triple Count After Generation

```
15,255 total triples (regenerated after all M2/M3 fixes incl. FIX-07)
2,229 distinct subject IRIs

Breakdown:
  Persons (ce:Person + subclasses)  1,441 subjects
  Participations                      586 subjects
  Episodes                             74 subjects
  Series                               76 subjects
  Films                                24 subjects
  Genres                               28 subjects
```

To recount:
```bash
python3 -c "from rdflib import Graph; g=Graph(); g.parse('output/cineexplorer_kg.ttl', format='turtle'); print(len(g))"
```

> **Sanity-check arithmetic.** 1,441 + 586 + 74 + 76 + 24 + 28 = 2,229 — matches the distinct-subject count, confirming every subject IRI in the KG corresponds to one of the six entity types. The 15,255 triples are spread across these subjects: persons average ~3 triples each (type, name, birth/death year, label), participations average ~6 (type, playedBy, participatesIn, role, job, label), titles average ~7–10 (type, title, original-title, year, runtime, genre links, language/region tags, person-link inverses, …). The full breakdown is what gets reported in the Q1–Q10 results in the report.

---

## Reading R2RML — Cheat Sheet

| Construct | Plain English |
|-----------|---------------|
| `<#X> a rr:TriplesMap` | "X" is a triple map. |
| `rr:logicalTable [ rr:tableName "t" ]` | Source rows = all rows of table `t`. |
| `rr:logicalTable [ rr:sqlQuery """SELECT ... """ ]` | Source rows = result of this SQL query. |
| `rr:subjectMap [ rr:template "..." ; rr:class :C ]` | Subject IRI is built from this template; assert `?subject rdf:type :C`. |
| `rr:predicateObjectMap [ rr:predicate :p ; rr:objectMap [ rr:column "C" ] ]` | For every row, emit `?subject :p "C-value"`. |
| `... rr:objectMap [ rr:column "C" ; rr:datatype xsd:T ]` | Object literal is typed `xsd:T`. |
| `... rr:objectMap [ rr:column "C" ; rr:language "en" ]` | Object is a language-tagged string `"value"@en`. |
| `... rr:objectMap [ rr:template "..." ; rr:termType rr:IRI ]` | Object is an IRI built from the template. |
| (R2RML §10.3) | If any column referenced by an `rr:template` or `rr:column` is NULL in a row, that predicate-object map is skipped for the row. |
| Same template across maps | Triples about the same IRI merge on the same subject — no explicit join needed. |

> **Reminder**: every triple map runs independently. The "graph" effect — that all triples about Russell Crowe end up describing one node — is achieved purely by every relevant map building the *same* IRI string for him. The unification is a property of the RDF model, not of R2RML itself.

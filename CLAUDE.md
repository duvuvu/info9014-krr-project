# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CineExplorer** — an intelligent cinema exploration platform built for INFO9014 (Knowledge Representation and Reasoning) at ULiège. The project integrates IMDb relational data with Wikidata to build a Knowledge Graph supporting semantic queries and Bacon Number (actor connection) discovery. Authors: Dawid Raczkowski, Hoang Linh Bui, Duy Vu Dinh.

## Commands

### Database (Docker)
```bash
# Start MySQL + phpMyAdmin
docker compose -f IMDB/docker-compose.yml up -d

# Stop (keep data)
docker compose -f IMDB/docker-compose.yml down

# Full reset (wipe data)
docker compose -f IMDB/docker-compose.yml down -v
```

Access:
- **phpMyAdmin**: http://localhost:8080 (user: `imdb_user`, pass: `imdb_pass`)
- **MySQL direct**: port `3307` (root pass: `root`, db: `imdb`)

### R2RML Mapping (Milestone 3)
```bash
# Run from project root — requires Docker DB to be running
java -jar tools/r2rml/r2rml.jar mapping/mapping.properties
# Output written to output/cineexplorer_kg.ttl
```

## Architecture

### Current State (Milestone 1 complete, Milestone 2 in progress)
The relational database layer is done. The OWL 2 ontology (`cineexplorer_ontology.ttl`) is drafted at v5. Milestones 3–4 (RML mappings, SPARQL queries) are pending.

```
cineexplorer_ontology.ttl  — OWL 2 ontology in Turtle format (Milestone 2)
m2_missing_items.md        — Pending M2 items (author annotations + sample individuals)
IMDB/
  docker-compose.yml     — MySQL 8.0 + phpMyAdmin services
  imdb-schema.sql        — Schema DDL + LOAD DATA INFILE for CSV bulk load
  csv-data/              — Sampled IMDb data (tab-separated, null=\N)
mapping/
  cineexplorer_mapping.ttl — R2RML mapping (Milestone 3)
  mapping.properties       — JDBC connection + paths config for r2rml.jar
output/                  — Generated RDF output written here after running r2rml.jar
tools/
  r2rml/
    r2rml.jar            — R2RML processor (copied from lab5)
    dependency/          — JDBC drivers and Jena libs required by r2rml.jar
docs/
  ERD.drawio / ERD.pdf / figs/ERD.png  — Entity-relationship diagrams
labsession/              — Reference only: lab exercises (lab0–lab6, linked_data_tutorial)
```

### Linked Data / Ontology Tooling

- **Protégé** — OWL ontology editing and reasoning (open `cineexplorer_ontology.ttl` directly)
- **r2rml.jar** — R2RML processor at `tools/r2rml/r2rml.jar`; config in `mapping/mapping.properties`
- **Apache Jena / Fuseki** or **GraphDB** — SPARQL endpoint for Milestone 4 queries
- **Brwsr** (`clariah/brwsr`) — Linked Data browser; Docker Compose pattern in `labsession/linked_data_tutorial/`
- **WIDOCO** — optional HTML documentation generation from the ontology

### Database Schema (MySQL `imdb`)

**Reference/lookup tables**: `category`, `content_type`, `genre`, `language`, `region`, `role`, `title_type`

**Core entity tables**:
- `title` — movies, TV shows, etc. (tconst PK, linked to content_type, title_type)
- `talent` — actors/crew (nconst PK, birth/death years)

**Junction/relationship tables**:
- `title_aka` — alternative titles per region/language
- `title_genre` — title ↔ genre (many-to-many)
- `title_episode` — TV episode metadata (parent series reference)
- `title_principal` — principal cast/crew per title
- `principal_role` — specific character/role within a principal assignment
- `talent_role` — talent ↔ role skills (many-to-many)
- `talent_title` — talent ↔ title knownFor relationships

### Ontology (`cineexplorer_ontology.ttl`)

**Namespace**: `https://example.org/cineexplorer/ontology#`  
**Format**: Turtle / OWL 2

**Classes** (top-level disjoint: `CreativeWork`, `Person`, `Genre`, `Participation`):
- `Person` → `Actor`, `Composer`, `Director`, `Editor`, `Writer` (not disjoint — one person may hold multiple roles)
- `CreativeWork` → `Film`, `Series`, `Episode` (disjoint from each other; `Episode` has `partOfSeries` exactly 1, functional)
- `Participation` — reification node linking exactly one `Person` to exactly one `CreativeWork`, carrying `characterName`, `participationRole`

**Key object properties**:
- `workedFor` / `employed` — top-level inverses between `Person` and `CreativeWork`
- Role-specific sub-properties: `actedIn`/`hasActor`, `directed`/`directedBy`, `wrote`/`writtenBy`, `edited`/`editedBy`, `composedFor`/`composedBy`
- `knownFor` — sub-property of `workedFor` for notable associations
- `hasGenre`/`isGenreOf`, `hasEpisode`/`partOfSeries`
- `playedBy`/`hasRole`, `participatesIn` — link `Participation` to `Person`/`CreativeWork`
- `sameAsExternal` — maps local resources to Wikidata equivalents (max cardinality 1)
- `workedWith` — symmetric, derived; used for Bacon Number graph traversal

**Key data properties** on `Person`: `personName`, `birthYear`, `deathYear`; on `CreativeWork`: `workTitle`, `releaseYear`, `runtimeMinutes`, `isAdult`, `language`, `region`; on `Participation`: `characterName`, `participationRole`; on `Episode`: `episodeNumber`, `seasonNumber`; on `Genre`: `genreName`

### Milestones (from project statement)

| # | Name | Key Deliverables |
|---|------|-----------------|
| 1 | Database | ERD, SQL DDL dump, populated instances, technical report |
| 2 | Ontology Engineering | OWL 2 ontology (namespace, concepts, relations, individuals), human-readable labels/glosses, technical report; optionally WIDOCO docs |
| 3 | Annotating the IS | R2RML or RML mappings, generated RDF, technical report covering IRI strategies |
| 4 | Using the KG | Deployment, non-trivial SPARQL queries (subqueries, federated, paths, aggregates, negation), demonstrator (SHACL / rule languages / big data KG topic) |

**Collaboration**: Groups may share a common ontology core. All co-authors must appear as ontology annotations. Technical reports are per-group; shared paragraphs need a footnote citation.

## Data Notes

- CSV files use tab (`\t`) as separator and `\N` to represent NULL
- IMDb identifiers: `tconst` (titles, e.g. `tt0000001`), `nconst` (people, e.g. `nm0000001`)
- Schema uses `LOAD DATA INFILE` — the Docker volume mounts `/IMDB/csv-data` into the MySQL container at `/var/lib/mysql-files/`
- Data is a non-commercial sample from the northcoder IMDb dataset
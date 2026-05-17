# CineExplorer — KRR Project (INFO9014, ULiège)

## Project Identity
- **Name:** CineExplorer
- **Course:** INFO9014 — Knowledge Representation and Reasoning, Prof. Christophe Debruyne, ULiège
- **Team:** Dawid RACZKOWSKI (s200735), Hoang Linh BUI (s2503303), Duy Vu DINH (s2401627)
- **Current branch:** `develop`

## Repository Layout
```
info9014-krr-project/
├── database/                    # MySQL source DB (was IMDB/)
│   ├── imdb-schema.sql          #   DDL + LOAD DATA (MySQL 8, InnoDB)
│   ├── csv-data/                #   16 TSV source files
│   ├── docker-compose.yml       #   MySQL 8 (port 3307) + phpMyAdmin (port 8080)
│   └── README.md
├── ontology/                    # OWL 2 DL ontology
│   └── cineexplorer_ontology.ttl
├── mapping/                     # R2RML mapping
│   ├── cineexplorer_mapping.ttl
│   └── mapping.properties       # JDBC: localhost:3307/imdb, imdb_user/imdb_pass
├── tools/r2rml/                 # R2RML processor (canonical location)
│   ├── r2rml.jar
│   └── dependency/              # Required JARs (r2rml is not a fat jar)
├── output/                      # Generated artifacts
│   └── cineexplorer_kg.ttl      #   KG — 15,255 triples, 2,229 subjects
├── sparql/                      # M4: SPARQL query files
│   ├── q01_films_genres.sparql
│   ├── ...
│   └── results/                 #   CSV exports / screenshots per query
├── deployment/                  # M4: Fuseki + Brwsr
│   ├── docker-compose.yml       #   Fuseki (port 3030) + Brwsr (port 5000) — separate from database/
│   └── README.md
├── report/
│   ├── main.tex                 # LaTeX entry point
│   ├── references.bib
│   ├── sec/                     # §0–§12 + appendices A–C
│   └── fig/
└── docs/                        # Internal working docs (not submitted)
    ├── plan.md
    ├── ERD.drawio
    └── figs/ERD.png
```

## Technology Stack
| Tool | Version | Purpose |
|------|---------|---------|
| MySQL | 8 (Docker) | Source database, port **3307** |
| phpMyAdmin | Docker | DB admin UI at http://localhost:8080 |
| R2RML processor | `r2rml.jar` | Converts DB → RDF KG |
| Protégé | 5.6.9 | OWL editor at `~/All/Protege-5.6.9/run.sh` |
| Apache Fuseki | 5.5.0 (`secoresearch/fuseki`) | SPARQL triplestore, port **3030**, dataset `cineexplorer` |
| Brwsr | `clariah/brwsr:latest` (Docker) | Linked Data browser, port **5000**, content negotiation |
| HermiT | (inside Protégé) | OWL 2 DL reasoner |

## Key Commands
```bash
# Start source database (MySQL)
cd database && docker compose up -d
# MySQL direct access
docker exec -it imdb-mysql mysql -u imdb_user -pimdb_pass imdb

# Run R2RML mapping (must run from inside mapping/)
cd mapping && java -jar ../tools/r2rml/r2rml.jar mapping.properties

# Start Fuseki + Brwsr (M4)
cd deployment && docker compose up -d
# Load KG into Fuseki
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @output/cineexplorer_kg.ttl \
  -H "Content-Type: text/turtle"
# Fuseki admin UI: http://localhost:3030
# SPARQL endpoint: http://localhost:3030/cineexplorer/query
# Brwsr LD browser: http://localhost:5000
# Example person:  http://localhost:5000/data/person/nm0000102

# Open Protégé
~/All/Protege-5.6.9/run.sh

# Check KG triple count
python3 -c "from rdflib import Graph; g=Graph(); g.parse('output/cineexplorer_kg.ttl', format='turtle'); print(len(g))"
```

## Ontology Quick Reference
- **Namespace:** `http://cineexplorer.local/ontology#` (prefix `ce:`)
- **Data IRIs:** `http://cineexplorer.local/data/{title|person|genre|participation}/...`
- **Profile:** OWL 2 DL (verified HermiT in Protégé)
- **Classes:** `CreativeWork` → {`Film`, `Series`, `Episode`} (disjoint); `Person` → {`Actor`,`Director`,`Writer`,`Editor`,`Composer`} (not disjoint); `Genre`; `Participation`
- **Key properties:** `workedFor`/`employed`, `actedIn`/`hasActor`, `directed`/`directedBy`, `wrote`/`writtenBy`, `edited`/`editedBy`, `composedFor`/`composedBy`, `partOfSeries`/`hasEpisode`, `playedBy`/`hasRole`, `participatesIn`, `workedWith` (symmetric), `sameAsExternal`, `knownFor`

## Database Quick Reference
- **DB name:** `imdb`; **port:** 3307; **user/pass:** `imdb_user`/`imdb_pass`
- **Scale:** 174 titles, 1,441 persons, 587 principal credits, 74 episodes, 28 genres
- **Key tables:** `title`, `talent`, `title_principal`, `principal_role`, `title_episode`, `title_genre`, `title_aka`, `talent_title`, `talent_role`
- **IRI keys:** `TITLE_ID` = IMDb `tconst` (e.g. `tt0000001`), `TALENT_ID` = IMDb `nconst` (e.g. `nm0000001`)

## Milestone Status
| Milestone | Status | Notes |
|-----------|--------|-------|
| M0: Groups | Done | |
| M1: Database | Done | IMDb sample, normalized, FK-enforced |
| M2: Ontology | Done — fixes applied | FIX-01,02,04,06,07,08,09 Solved |
| M3: Mappings | Done — fixes applied | FIX-01,02,03,04,05,07,10,11,12,13,14 Solved |
| M4: Deployment + SPARQL + Demonstrator | **Done** | Fuseki + Brwsr deployed; Q1–Q10 tested; Bacon + SHACL demos; §8–§10 written |

## Known Issues (from self-review + professor feedback)
See `docs/plan.md` for the full fix list. All critical/high/medium fixes applied except:
- FIX-05: `sameAsExternal` — resolved at M4 via Q7 Wikidata federation (BIND+REPLACE+SERVICE, no materialisation needed)

## Course Material Paths
```
~/Documents/Obsidian Vault/10_Areas/Master/Courses/INFO9014-1_KRR/
├── Lectures/        # L00–L12 markdown notes
└── Assignments/     # EX00–EX07 markdown solutions
```
Most relevant: L07 (OWL), L08 (R2RML), L09 (Linked Data), L05 (SPARQL), EX05 (R2RML lab), EX07 (Fuseki + Brwsr tutorial)

## Reference Documents

| Document | Path | Status |
|----------|------|--------|
| Database (tables, schema, DDL) | `docs/db_reference.md` | GOOD |
| Information System (ERD, SQL design) | `docs/is_reference.md` | GOOD |
| Ontology (all classes, properties, axioms, issues) | `docs/ontology_reference.md` | GOOD |
| Mapping (all triple maps, issues) | `docs/mapping_reference.md` | GOOD |
| SPARQL queries Q1–Q10 (queries, results, explanations) | `docs/sparql_reference.md` | GOOD |
| Non-trivial demonstrator (Bacon number + SHACL) | `docs/demonstrator_reference.md` | GOOD |
| Official IMDb migration plan (active) | `docs/plan.md` | active |
| Filtered-IMDb data inspection (Phase 2 input) | `docs/tsv_inspection.md` | active |
| Full-IMDb raw data analysis (Phase 2 input, source: `notebooks/`) | `docs/raw_imdb_analysis.md` | active |
| ERD investigation (Phase 2 working doc — open questions, decisions log) | `docs/erd_investigation.md` | active |
| ERD specification (canonical ERD + relational + SQL listing for the report) | `docs/erd_specification.md` | active |
| Archived plans (M2/M3 fix cycle + M4 roadmap, all Solved) | `docs/archive/` | archived |
| Report sections → ontology/mapping cross-ref | `docs/report_reference.md` | active |
| Course lectures and labs | `docs/course_reference.md` | reference |

## Workflow Rules

### Rule 1 — Receiving professor feedback
When the user sends a piece of professor feedback:
1. Use `docs/report_reference.md` to identify which report section the feedback targets and the corresponding ontology/mapping file:line
2. Review `docs/ontology_reference.md`, `docs/mapping_reference.md`, and `docs/plan.md`
3. Identify which fix (FIX-XX) it corresponds to, or create a new one
4. Explain WHY it is a problem (connect to KRR course principles via `docs/course_reference.md`), WHAT the fix is, and WHAT report section needs updating
5. Add or update the entry in `docs/plan.md` with the solution
6. Do NOT implement until the user confirms

### Rule 2 — Proposing a fix
After identifying a fix (from Rule 1), write the full proposal into `docs/plan.md` BEFORE implementing:
- Include the exact text/code that will change (diff-style or full replacement block)
- Include which files and line numbers are affected
- Do NOT edit any source file yet — wait for explicit user approval

### Rule 3 — After a fix is approved and implemented
1. Update `docs/ontology_reference.md` — remove or update the `[FIX-XX]` tags for affected classes/properties
2. Update `docs/mapping_reference.md` — remove or update the `[FIX-XX]` tags for affected triple maps
3. Mark the fix as Solved in `docs/plan.md`
4. Regenerate the KG to verify: `cd mapping && java -jar ../tools/r2rml/r2rml.jar mapping.properties`
5. Note the new triple count in the mapping reference

## Milestone 4 Plan (see docs/plan.md for details)
1. **Deploy** KG in Apache Fuseki (Docker, port 3030)
2. **SPARQL queries** — must include: subqueries, federated (SERVICE → Wikidata), property paths, aggregates, negation as failure
3. **Non-trivial demonstrator** — Bacon number path analysis + SHACL validation (or Wikidata federation)
4. **Report sections** to add: Deployment & Demonstration, Non-trivial Demonstrator

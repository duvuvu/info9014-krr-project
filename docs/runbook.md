# CineExplorer Runbook

Step-by-step instructions to reproduce the full CineExplorer pipeline from scratch on a Linux/macOS machine. Covers source database, R2RML mapping, Fuseki deployment, and SPARQL querying via both the Fuseki UI and the command line.

All commands assume the project root as the working directory:

```bash
cd ~/All/82_Master_Uliege/_Y2Q2/KRR/info9014-krr-project
```

---

## 0. Prerequisites

| Tool | Version | Verify with |
|---|---|---|
| Docker + Docker Compose v2 | any recent | `docker compose version` |
| Java | 11+ | `java -version` |
| Python | 3.8+ | `python3 --version` |
| `rdflib` (Python) | any | `python3 -c "import rdflib"` |
| `pyshacl` | 0.31+ (only for SHACL) | `pyshacl --version` |
| `curl` | any | `curl --version` |

---

## 1. Start the source database (MySQL)

```bash
cd database && docker compose up -d && cd ..
```

This starts:

- **MySQL** on port `3307` (user `imdb_user` / password `imdb_pass`, database `imdb`)
- **phpMyAdmin** on `http://localhost:8080` — browse source tables in the browser

**Verify** (wait ~30 s for MySQL to initialise):

```bash
docker exec imdb-mysql mysql -uimdb_user -pimdb_pass imdb -e "SELECT COUNT(*) FROM title;"
```

---

## 2. Generate the knowledge graph (R2RML)

> Only needed if you change the mapping or schema. Skip if the committed `output/cineexplorer_kg.ttl` is current.

```bash
cd mapping && java -jar ../tools/r2rml/r2rml.jar mapping.properties && cd ..
```

This reads `mapping/cineexplorer_mapping.ttl`, executes the embedded SQL against MySQL on port 3307, and writes the resulting RDF to `output/cineexplorer_kg.ttl`.

**Verify**:

```bash
python3 -c "from rdflib import Graph; g=Graph(); g.parse('output/cineexplorer_kg.ttl', format='turtle'); print('Triples:', len(g))"
```

Expect ~1.6 M triples on the `feature/imdb-official` branch.

---

## 3. Start Fuseki + Brwsr

```bash
cd deployment && docker compose up -d && cd ..
```

This starts:

- **Fuseki** on `http://localhost:3030` (SPARQL endpoint + admin UI; login `admin` / `admin`)
- **Brwsr** on `http://localhost:5000` (Linked Data browser; example entry: `http://localhost:5000/data/person/nm0000102`)

**Verify** `docker compose ps` shows both `cineexplorer-fuseki` and `cineexplorer-brwsr` as `Up`.

---

## 4. Create the dataset and load the KG (one-time)

The first time you start Fuseki, the dataset doesn't exist. Run these three `curl` commands once:

```bash
# 4a. Create the empty TDB2 dataset
curl -u admin:admin -X POST http://localhost:3030/\$/datasets \
  -d "dbName=cineexplorer&dbType=tdb2"

# 4b. Load the ontology (TBox)
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @ontology/cineexplorer_ontology.ttl \
  -H "Content-Type: text/turtle"

# 4c. Load the KG (ABox)
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @output/cineexplorer_kg.ttl \
  -H "Content-Type: text/turtle"
```

**Verify triple count**:

```bash
curl -s -X POST http://localhost:3030/cineexplorer/query \
  -H "Accept: application/sparql-results+json" \
  -H "Content-Type: application/sparql-query" \
  --data-binary "SELECT (COUNT(*) AS ?n) WHERE { ?s ?p ?o }"
```

Expect ~1.6 M triples (1,611,676 plus ~250 ontology triples).

---

## 5. Running SPARQL queries via the Fuseki UI

### 5.1 Open the dataset

In your browser, go to `http://localhost:3030/`. You'll see a list of datasets. Click **`/cineexplorer`**.

### 5.2 Click the "query" tab

Near the top of the dataset page is a row of tabs: `info` · `query` · `edit` · `upload files` · `manage`. Click **`query`**.

The screen splits into:

- **Left panel** — query editor (YASQE; syntax highlighting and autocomplete)
- **Right panel** — empty results area
- **Top controls** — `Run` button, format selector (Table / Raw Response), download icon

### 5.3 Paste a query and run it

Open any `sparql/*.sparql` file, copy the contents, paste into the editor, click **`Run`**.

#### Example A — a `SELECT` query (Q1)

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

SELECT ?title ?genre ?runtime
WHERE {
  ?film a ce:Film ;
        ce:workTitle ?title ;
        ce:runtimeMinutes ?runtime ;
        ce:hasGenre ?g .
  ?g ce:genreName ?genre .
}
ORDER BY DESC(?runtime)
LIMIT 20
```

You'll get a 3-column table. Use the format dropdown to switch between Table, JSON, XML, CSV. Use the download icon to save the result.

#### Example B — an `ASK` query (Q12, pairwise Bacon distance)

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

ASK {
  BIND(<http://cineexplorer.local/data/person/nm0000102> AS ?source)  # Kevin Bacon
  BIND(<http://cineexplorer.local/data/person/nm0000158> AS ?target)  # Tom Hanks
  ?source (ce:workedFor/ce:employed){1,1} ?target .
  FILTER(?source != ?target)
}
```

Result: a green box with **"true"** (Bacon distance = 1, via *Apollo 13*).

To check distance 2 / 3, change `{1,1}` to `{2,2}` / `{3,3}` and re-run. The smallest `k` returning `true` is the Bacon distance.

#### Example C — a `CONSTRUCT` query (Q11, workedWith materialisation)

```sparql
PREFIX ce: <http://cineexplorer.local/ontology#>

CONSTRUCT { ?p1 ce:workedWith ?p2 . }
WHERE {
  ?p1 ce:workedFor ?work .
  ?p2 ce:workedFor ?work .
  FILTER(?p1 != ?p2)
}
LIMIT 100
```

The `LIMIT 100` is essential in the browser — the unbounded query produces ~1.68 M triples and the UI will freeze trying to render them. For the full result, run via `curl` (see §6).

The result format defaults to Turtle. Use the dropdown to switch to JSON-LD, N-Triples, etc.

### 5.4 Save, share, export

- **Download** — CSV/JSON/Turtle download via the icon next to the format dropdown.
- **Permalink** — the URL in the address bar updates as you edit; you can bookmark or share a query.
- **Versioned queries** — paste into a `.sparql` file under `sparql/` for git-tracked, reproducible work.

---

## 6. Running SPARQL queries via the command line

For batch use, scripting, or queries too large for the UI (like full Q11):

```bash
ENDPOINT="http://localhost:3030/cineexplorer/query"

# Run a saved query, get CSV
curl -s -X POST "$ENDPOINT" \
  -H "Accept: text/csv" \
  -H "Content-Type: application/sparql-query" \
  --data-binary @sparql/q01_films_genres.sparql

# Run the full Q11 CONSTRUCT (1.68M triples → file)
curl -s -X POST "$ENDPOINT" \
  -H "Accept: text/turtle" \
  -H "Content-Type: application/sparql-query" \
  --data-binary @sparql/q11_construct_workedwith.sparql \
  -o sparql/results/q11_workedwith.ttl

# Run Q12 iteration (Bacon distance for several anchor pairs)
python3 sparql/run_pairwise_bacon.py
```

### Run all queries and save CSV results

```bash
ENDPOINT="http://localhost:3030/cineexplorer/query"
for f in sparql/q0*.sparql; do
  name=$(basename "$f" .sparql)
  curl -s -X POST "$ENDPOINT" \
    -H "Accept: text/csv" \
    -H "Content-Type: application/sparql-query" \
    --data-binary "@$f" > "sparql/results/${name}.csv"
  echo "Saved ${name}.csv ($(wc -l < sparql/results/${name}.csv) rows)"
done
```

> **Note on Q7 (Wikidata federation):** requires internet access. The query calls `https://query.wikidata.org/sparql` for 10 *Les Misérables* cast members. Typical wall time ~5 s; can be longer if Wikidata is rate-limited.

---

## 7. SHACL validation

```bash
# Requires pyshacl installed
# Install: pip install pyshacl  (or conda install -c conda-forge pyshacl)

# Run WITHOUT ontology inference — expected to fail on Participation cardinalities
pyshacl \
  -s sparql/cineexplorer_shapes.ttl \
  -d output/cineexplorer_kg.ttl \
  -f human 2>&1 | grep -E "Conforms|Results"

# Run WITH RDFS inference — expected to conform
pyshacl \
  -s sparql/cineexplorer_shapes.ttl \
  -d output/cineexplorer_kg.ttl \
  -e ontology/cineexplorer_ontology.ttl \
  --inference rdfs \
  -f human 2>&1 | grep -E "Conforms|Results"
```

The violations without inference are intentional and demonstrate the OWA vs CWA distinction (see §10 of the report). With RDFS inference enabled, the KG fully conforms.

---

## 8. Bacon-number demo

```bash
ENDPOINT="http://localhost:3030/cineexplorer/query"

# Q6 — direct collaborators of Kevin Bacon (Bacon distance 1)
curl -s -X POST "$ENDPOINT" \
  -H "Accept: text/csv" \
  -H "Content-Type: application/sparql-query" \
  --data-binary @sparql/q06_bacon_number.sparql

# Q6b — persons reachable within 2 collaboration hops
curl -s -X POST "$ENDPOINT" \
  -H "Accept: text/csv" \
  -H "Content-Type: application/sparql-query" \
  --data-binary @sparql/q06b_bacon_2hops.sparql

# Q12 — pairwise Bacon distance for several pairs (Hanks, Newman, Tracy, Steiner, Marx)
python3 sparql/run_pairwise_bacon.py
cat sparql/results/q12_pairwise_bacon_summary.md
```

See [`docs/demonstrator_reference.md`](demonstrator_reference.md) for full discussion.

---

## 9. Browse as Linked Data (Brwsr)

Navigate to `http://localhost:5000` in a browser. Brwsr uses HTTP 303 content negotiation:

```bash
# HTML view (what a browser sees)
curl -L -H "Accept: text/html" http://localhost:5000/data/person/nm0000102

# RDF/Turtle view (what a machine sees)
curl -H "Accept: text/turtle" http://localhost:5000/data/person/nm0000102
```

Suggested starting points:

- `http://localhost:5000/data/person/nm0000102` — Kevin Bacon
- `http://localhost:5000/data/person/nm0000158` — Tom Hanks
- `http://localhost:5000/data/title/tt1707386` — Les Misérables
- `http://localhost:5000/ontology` — ontology terms

---

## 10. Daily operations cheat-sheet

| Task | Command |
|---|---|
| Start everything | `cd database && docker compose up -d && cd ../deployment && docker compose up -d && cd ..` |
| Stop everything | `cd deployment && docker compose down && cd ../database && docker compose down && cd ..` |
| Regenerate the KG | `cd mapping && java -jar ../tools/r2rml/r2rml.jar mapping.properties && cd ..` |
| Re-load the KG into Fuseki | Repeat §4c with `PUT` to overwrite, or delete + recreate the dataset |
| Triple count in deployed KG | `curl -s -X POST http://localhost:3030/cineexplorer/query -H "Accept: application/sparql-results+json" -H "Content-Type: application/sparql-query" --data-binary "SELECT (COUNT(*) AS ?n) WHERE { ?s ?p ?o }"` |

---

## 11. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `curl: (7) Failed to connect to localhost port 3030` | Fuseki not running | `cd deployment && docker compose up -d` and wait 10 s |
| Fuseki UI says "0 triples" after load | Dataset created but load failed | Re-run §4b and §4c; check `curl` output for errors |
| R2RML jar errors with `Communications link failure` | MySQL not running on port 3307 | `cd database && docker compose up -d` |
| Browser shows raw IRIs instead of `ce:Person` | No `PREFIX` declared in the query | Add `PREFIX ce: <http://cineexplorer.local/ontology#>` at the top |
| Q11 in the UI freezes the browser | 1.68 M triples is too many to render | Add `LIMIT 1000` to the query, or run via curl into a file |
| Wikidata federation (Q7) returns nothing | Wikidata endpoint rate-limited or down | Retry after 30 s; or run via curl rather than the UI |
| `docker compose up` says "port already in use" | Another service on that port | `docker ps` to find it; `docker stop <id>` |

---

## 12. Resetting from scratch

```bash
# Stop and remove all containers + volumes
cd deployment && docker compose down -v && cd ..
cd database && docker compose down -v && cd ..

# Clear generated files
rm -f output/cineexplorer_kg.ttl
rm -f sparql/results/q11_workedwith.ttl   # large, gitignored
```

Then restart from §1. The `-v` flag deletes the Fuseki volume, so the dataset is gone and you'll need to recreate it (§4a–4c).

---

## 13. Reference — access points and expected counts

### Access points

| Service | URL | Purpose |
|---|---|---|
| Fuseki admin UI | <http://localhost:3030> | Dataset management, query editor |
| SPARQL endpoint | <http://localhost:3030/cineexplorer/query> | SPARQL 1.1 queries |
| Brwsr LD browser | <http://localhost:5000> | Linked Data navigation |
| phpMyAdmin | <http://localhost:8080> | MySQL source DB admin |

### Expected counts (`feature/imdb-official` branch)

| Item | Count |
|---|---|
| Total triples in Fuseki | ~1,611,676 |
| `ce:Film` | 4,214 |
| `ce:Series` | 622 |
| `ce:Episode` | 139 |
| `ce:Person` | 38,067 |
| `ce:Genre` | 26 |
| `ce:Participation` | 105,964 |
| SPARQL query files | 13 (Q1–Q10 + Q6b + Q11 + Q12) |
| SHACL shapes | 4 |
| Q11 output triples (`workedWith`) | 1,679,610 |

### Project reference docs

- [`docs/sparql_reference.md`](sparql_reference.md) — every Q1–Q12 with line-by-line explanation
- [`docs/ontology_reference.md`](ontology_reference.md) — every class and property
- [`docs/mapping_reference.md`](mapping_reference.md) — every triple map
- [`docs/demonstrator_reference.md`](demonstrator_reference.md) — Bacon number and SHACL demos

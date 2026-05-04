# CineExplorer — Runbook

Step-by-step instructions to reproduce the full CineExplorer pipeline from scratch on a Linux machine with Docker and Java installed.

---

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Docker + Docker Compose v2 | any recent | `docker compose version` |
| Java | 8+ | `java -version` |
| Python | 3.8+ | `python3 --version` |
| pyshacl | 0.31+ | `conda run -n base pyshacl --version` |
| curl | any | `curl --version` |

---

## Part 1 — Source Database (M1)

```bash
# From project root
cd database && docker compose up -d

# Verify MySQL is up (takes ~10 sec)
docker exec imdb-mysql mysql -u imdb_user -pimdb_pass -e "SELECT COUNT(*) FROM imdb.title;"
# Expected: 174

# phpMyAdmin available at http://localhost:8080
```

---

## Part 2 — Regenerate the Knowledge Graph (M3)

> Only needed if you change the mapping or schema. Skip if using the committed `output/cineexplorer_kg.ttl`.

```bash
# Requires database running (Part 1)
cd mapping && java -jar ../tools/r2rml/r2rml.jar mapping.properties
# Output: ../output/cineexplorer_kg.ttl

# Verify triple count
python3 -c "
from rdflib import Graph, Namespace, RDF
CE = Namespace('http://cineexplorer.local/ontology#')
g = Graph(); g.parse('output/cineexplorer_kg.ttl', format='turtle')
print(f'Total triples: {len(g)}')
for cls in ['Film','Series','Episode','Person','Genre','Participation']:
    print(f'  {cls}: {len(list(g.subjects(RDF.type, CE[cls])))}')
"
# Expected:
#   Total triples: 15495
#   Film: 24  Series: 76  Episode: 74  Person: 1441  Genre: 28  Participation: 586
```

---

## Part 3 — Deploy Fuseki + Brwsr (M4)

```bash
# From project root
cd deployment && docker compose up -d

# Check both containers are running
docker compose ps
# Expected: cineexplorer-fuseki Up, cineexplorer-brwsr Up
```

### 3a — Create the TDB2 dataset (once only)

```bash
curl -u admin:admin -X POST http://localhost:3030/$/datasets \
  -d "dbName=cineexplorer&dbType=tdb2"
# Expected: HTTP 200 or 409 (already exists)
```

### 3b — Load ontology

```bash
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @ontology/cineexplorer_ontology.ttl \
  -H "Content-Type: text/turtle"
# Expected: HTTP 200
```

### 3c — Load knowledge graph

```bash
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @output/cineexplorer_kg.ttl \
  -H "Content-Type: text/turtle"
# Expected: HTTP 200
```

### 3d — Verify triple count

```bash
curl -s -G http://localhost:3030/cineexplorer/query \
  --data-urlencode "query=SELECT (COUNT(*) AS ?n) WHERE { ?s ?p ?o }" \
  -H "Accept: application/sparql-results+json"
# Expected: "n": "15800"  (15495 KG + 305 ontology)
```

---

## Part 4 — Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| Fuseki web UI | http://localhost:3030 | Dataset management, query editor |
| SPARQL endpoint | http://localhost:3030/cineexplorer/query | SPARQL 1.1 queries |
| Brwsr LD browser | http://localhost:5000 | Linked Data navigation |
| Example person | http://localhost:5000/data/person/nm0000128 | Russell Crowe (Les Misérables) |
| phpMyAdmin | http://localhost:8080 | MySQL source DB admin |

---

## Part 5 — Run SPARQL Queries (M4-02)

All `.sparql` files are in `sparql/`. Run against the Fuseki endpoint:

```bash
ENDPOINT="http://localhost:3030/cineexplorer/query"

# Example: Q1 — films with genres ordered by runtime
curl -s -G "$ENDPOINT" \
  --data-urlencode "$(cat sparql/q01_films_genres.sparql)" \
  -H "Accept: text/csv"

# Or using --data-urlencode with file content:
curl -s "$ENDPOINT" \
  --data-urlencode "query=$(cat sparql/q01_films_genres.sparql)" \
  -H "Accept: text/csv"
```

### Run all queries and save results

```bash
ENDPOINT="http://localhost:3030/cineexplorer/query"
for f in sparql/q0*.sparql; do
  name=$(basename "$f" .sparql)
  curl -s "$ENDPOINT" \
    --data-urlencode "query=$(cat $f)" \
    -H "Accept: text/csv" > "sparql/results/${name}.csv"
  echo "Saved ${name}.csv ($(wc -l < sparql/results/${name}.csv) rows)"
done
```

> **Note on Q7 (Wikidata federation):** requires internet access from the host. The query uses a `VALUES` set of 10 persons from *Les Misérables* and calls `https://query.wikidata.org/sparql`. Timeout: ~30 seconds.

---

## Part 6 — SHACL Validation (M4-03-B)

```bash
# Requires: conda with pyshacl installed
# Install: conda install -n base -c conda-forge pyshacl

# Run WITHOUT ontology inference (shows 586 violations — expected)
conda run -n base pyshacl \
  -s sparql/cineexplorer_shapes.ttl \
  -d output/cineexplorer_kg.ttl \
  -f human 2>&1 | grep -E "Conforms|Results"
# Expected: Conforms: False — Results (586)

# Run WITH RDFS inference (should conform)
conda run -n base pyshacl \
  -s sparql/cineexplorer_shapes.ttl \
  -d output/cineexplorer_kg.ttl \
  -e ontology/cineexplorer_ontology.ttl \
  --inference rdfs \
  -f human 2>&1 | grep -E "Conforms|Results"
# Expected: Conforms: True
```

The 586 violations without inference are expected and intentional — they demonstrate the OWA vs CWA distinction (see §10 of the report). With RDFS inference enabled, the KG fully conforms.

---

## Part 7 — Bacon Number Demo (M4-03-A)

```bash
ENDPOINT="http://localhost:3030/cineexplorer/query"

# 1-hop: direct collaborators of Russell Crowe
curl -s "$ENDPOINT" \
  --data-urlencode "query=$(cat sparql/q06_bacon_number.sparql)" \
  -H "Accept: text/csv"
# Expected: 9 rows (Les Misérables cast)

# 2-hop: persons reachable within 2 hops
curl -s "$ENDPOINT" \
  --data-urlencode "query=$(cat sparql/q06b_bacon_2hops.sparql)" \
  -H "Accept: text/csv"
# Expected: same 9 rows (dataset is sparse; see §10 for connectivity analysis)

# Bridge title between two collaborators
curl -s "$ENDPOINT" --data-urlencode 'query=PREFIX ce: <http://cineexplorer.local/ontology#>
SELECT ?bridgeTitle WHERE {
  BIND(<http://cineexplorer.local/data/person/nm0000128> AS ?p1)
  BIND(<http://cineexplorer.local/data/person/nm0413168> AS ?p2)
  ?p1 ce:workedFor ?w . ?p2 ce:workedFor ?w . ?w ce:workTitle ?bridgeTitle .
}' -H "Accept: text/csv"
# Expected: "Les Misérables"
```

---

## Part 8 — Browse as Linked Data (M4 Brwsr)

Navigate to `http://localhost:5000` in a browser. Brwsr uses HTTP 303 content negotiation:

```bash
# HTML view (browser)
curl -L -H "Accept: text/html" \
  http://localhost:5000/data/person/nm0000128

# RDF/Turtle view
curl -H "Accept: text/turtle" \
  http://localhost:5000/data/person/nm0000128
```

Suggested starting points:
- `http://localhost:5000/data/person/nm0000128` — Russell Crowe
- `http://localhost:5000/data/title/tt1707386` — Les Misérables
- `http://localhost:5000/ontology` — ontology terms

---

## Teardown

```bash
# Stop Fuseki + Brwsr (data persists in Docker volume)
cd deployment && docker compose down

# Stop source database
cd database && docker compose down

# Remove Fuseki data volume (destructive — requires reloading KG)
docker volume rm deployment_fuseki_data
```

---

## Quick Reference: Expected Counts

| Item | Count |
|------|-------|
| KG triples | 15,495 |
| Ontology triples | 305 |
| Total in Fuseki | 15,800 |
| ce:Film | 24 |
| ce:Series | 76 |
| ce:Episode | 74 |
| ce:Person | 1,441 |
| ce:Genre | 28 |
| ce:Participation | 586 |
| SPARQL query files | 11 (q01–q10 + q06b) |
| SHACL shapes | 4 |

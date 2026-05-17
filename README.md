# CineExplorer — INFO9014 Knowledge Representation and Reasoning

**Course:** INFO9014 — Knowledge Representation and Reasoning, Prof. Christophe Debruyne, ULiège
**Team:** 
- Dawid RACZKOWSKI (s200735)
- Hoang Linh BUI (s2503303)
- Duy Vu DINH (s2401627)


## Overview

CineExplorer is a Knowledge Graph project built on a numVotes-ranked top-5,000-title slice of the official IMDb non-commercial dataset. The pipeline maps a normalised MySQL source to RDF via R2RML, producing 1.6 M triples that are deployed on Apache Fuseki with a Brwsr Linked Data front-end. The ontology sits in the OWL 2 QL profile.


## Repository structure

```
info9014-krr-project/
│
├── database/                          # MySQL source — IMDb non-commercial slice
│   ├── docker-compose.yml             #   MySQL on port 3307, phpMyAdmin on 8080
│   ├── imdb-schema.sql                #   DDL + LOAD DATA INFILE (loads filtered TSVs)
│   ├── etl/                           #   Data-ingestion pipeline
│   │   ├── download.sh                #     Downloads raw IMDb TSVs (~1.6 GB)
│   │   └── filter_top_n.sh            #     Filters to top-N by numVotes (default 5,000)
│   └── sources/imdb-official/
│       ├── raw/                       #   *.tsv.gz from datasets.imdbws.com
│       └── filtered/                  #   *.tsv after filter_top_n.sh (mounted into MySQL)
│
├── ontology/                          # OWL 2 QL ontology
│   └── cineexplorer_ontology.ttl
│
├── mapping/                           # R2RML mapping
│   ├── cineexplorer_mapping.ttl
│   └── mapping.properties             #   JDBC connection + I/O paths
│
├── tools/r2rml/                       # R2RML processor (r2rml.jar + dependencies)
│
├── output/                            # Generated knowledge graph
│   └── cineexplorer_kg.ttl            #   1.6 M triples (gitignored — re-generate locally)
│
├── sparql/                            # SPARQL queries
│   ├── q1_construct_workedwith.sparql
│   ├── q2_top_collaborators.sparql
│   ├── q3_wikidata_federation.sparql
│   ├── q4_pairwise_bacon.sparql
│   ├── run_pairwise_bacon.py          #   Iterated-ASK driver for Q4
│   └── results/                       #   CSV / Markdown result exports
│
├── shacl/                       # M4 — Non-trivial demonstrator files
│   ├── cineexplorer_episode_shape.ttl         # Shapes
│   ├── ...
│   ├── validation_report_episode_shape.ttl    # Validation reports
│   └── ...       
│
└── deployment/                        # Fuseki + Brwsr deployment
    └── docker-compose.yml             #   Fuseki on 3030, Brwsr on 5000
```


## Quick start — full pipeline from scratch

The pipeline has three independent stages: build the source database (ETL + Docker), run the R2RML mapping, and deploy the Fuseki triplestore. Each Docker stage is a separate Compose stack, so the only host dependencies are Docker, `bash` + `curl` (for the ETL scripts), Java (for `r2rml.jar`), and `python3` for the Q4 driver and query execution.

### 1. Build the source database

The database step has three sub-stages: the ETL pipeline (download and filter the IMDb TSVs), the Docker stack (MySQL + phpMyAdmin), and the schema load (the `imdb-schema.sql` script creates the canonical tables, runs `LOAD DATA INFILE` against the filtered TSVs, populates the canonical schema from staging, and adds foreign keys).

```bash
# 1a — Download the raw IMDb dumps (~1.6 GB compressed)
bash database/etl/download.sh
# Writes to database/sources/imdb-official/raw/*.tsv.gz

# 1b — Filter to the top-N titles by numVotes DESC (default N = 5,000)
bash database/etl/filter_top_n.sh 5000
# Writes to database/sources/imdb-official/filtered/*.tsv (~50 MB)

# 1c — Start MySQL + phpMyAdmin
cd database && docker compose up -d
cd ..

# 1e — Wait for MySQL to be healthy, then build the schema and load data
until docker exec imdb-mysql mysqladmin ping -h localhost -uroot -proot --silent; do sleep 2; done
docker exec -i imdb-mysql mysql -uroot -proot < database/imdb-schema.sql
```

The Docker stack exposes MySQL 8 on port 3307 (user `imdb_user`, password `imdb_pass`, database `imdb`) and phpMyAdmin on port 8080. The container mounts `database/sources/imdb-official/filtered/` into `/var/lib/mysql-files`, so the `LOAD DATA INFILE` statements in `imdb-schema.sql` read directly from the filtered TSV files. The schema script is idempotent (it drops the tables before recreating them), so it can be re-run after re-filtering with a different N. End-to-end load time at N = 5,000 is ~40–50 seconds.


### 2. Generate the knowledge graph

```bash
cd mapping && java -jar ../tools/r2rml/r2rml.jar mapping.properties
```

Outputs `output/cineexplorer_kg.ttl` — about 1.6 M triples. The mapping reads JDBC connection details from `mapping.properties` (defaults to the database started in step 1).

### 3. Deploy the triplestore

```bash
cd deployment && docker compose up -d
```

Brings up Apache Fuseki 5.5.0 on port 3030 and Brwsr on port 5000. Create the dataset and load both the ontology and the materialised KG into the default graph:

```bash
# Create the persistent TDB2 dataset (one-time)
curl -u admin:admin -X POST 'http://localhost:3030/$/datasets' \
  -d 'dbName=cineexplorer&dbType=tdb2'

# Load the ontology
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @ontology/cineexplorer_ontology.ttl \
  -H "Content-Type: text/turtle"

# Load the knowledge graph (~1.6 M triples, takes a minute)
curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data \
  --data-binary @output/cineexplorer_kg.ttl \
  -H "Content-Type: text/turtle"
```

Endpoints after this step:

| Endpoint | URL | Use |
|---|---|---|
| SPARQL query | `http://localhost:3030/cineexplorer/query` | All four queries below |
| Fuseki Web UI | `http://localhost:3030` | Admin, dataset management |
| Brwsr | `http://localhost:5000` | Linked-data browser (content negotiation on `http://cineexplorer.local/...`) |


### 4. Run the four queries

```bash
# Q1 — CONSTRUCT (count distinct ordered pairs the CONSTRUCT body would emit)
curl -s -X POST http://localhost:3030/cineexplorer/query \
  --data-urlencode 'query=PREFIX ce: <http://cineexplorer.local/ontology#>
    SELECT (COUNT(*) AS ?distinctPairs) WHERE {
      { SELECT DISTINCT ?p1 ?p2 WHERE {
          ?p1 ce:workedFor ?w . ?p2 ce:workedFor ?w . FILTER(?p1 != ?p2) } } }' \
  -H 'Accept: text/csv'
# Expected: 1,679,610 distinct workedWith triples (full CONSTRUCT body is in q1)

# Q2 — top-10 collaborator pairs (subquery + aggregation)
curl -s -X POST http://localhost:3030/cineexplorer/query \
  --data-urlencode 'query@sparql/q2_top_collaborators.sparql' \
  -H 'Accept: text/csv'

# Q3 — Wikidata federation (4-person panel — expect 3 returned rows)
curl -s -X POST http://localhost:3030/cineexplorer/query \
  --data-urlencode 'query@sparql/q3_wikidata_federation.sparql' \
  -H 'Accept: text/csv'

# Q4 — Bacon distance (Kevin Bacon → Tom Hanks, k=1; expect "true")
curl -s -X POST http://localhost:3030/cineexplorer/query \
  --data-urlencode 'query@sparql/q4_pairwise_bacon.sparql' \
  -H 'Accept: text/csv'

# Q4 — full pairwise driver (5 targets × k=1..3, writes a Markdown summary)
python3 sparql/run_pairwise_bacon.py
# Writes sparql/results/q4_pairwise_bacon_summary.md
```


## Knowledge graph at a glance

| Metric | Value |
|---|---:|
| Total triples (materialised base graph) | 1,611,676 |
| `ce:Person` instances | 38,067 |
| `ce:Participation` instances | 105,964 |
| `ce:CreativeWork` instances (Film + Series + Episode) | 4,975 |
| `ce:Genre` instances | 26 |
| `ce:workedWith` triples emitted by Q1 CONSTRUCT | 1,679,610 (≈1.04× base) |


## Entity-Relationship Diagram

<div style="display: flex; justify-content: space-around; align-items: center;">
    <img src="docs/figs/ERD.png" alt="CineExplorer ERD" style="width: 100%;"/>
</div>


## Ontology

- **Namespace:** `http://cineexplorer.local/ontology#` (prefix `ce:`)
- **Instance IRIs:** `http://cineexplorer.local/data/{type}/{id}` where `id` is the IMDb `tconst` or `nconst`
- **Profile:** OWL 2 QL — confirmed with Protégé's OWL Profile Checker; consistency verified with the HermiT reasoner at design time
- **Key classes:** `CreativeWork` → {`Film`, `Series`, `Episode`} (pairwise disjoint); `Person` → {`Actor`, `Director`, `Writer`, `Editor`, `Composer`}; `Genre`; `Participation`
- **OWL-beyond-RDFS constructs used:** `owl:inverseOf`, `owl:SymmetricProperty`, `owl:IrreflexiveProperty`, `owl:AsymmetricProperty`, `owl:disjointWith`, `owl:AllDisjointClasses`


## References

- IMDb. *IMDb Non-Commercial Datasets.* <https://developer.imdb.com/non-commercial-datasets/>
- R. Cyganiak, A. Das, J. Sequeda. *R2RML: RDB to RDF Mapping Language.* W3C Recommendation, 2012. <https://www.w3.org/TR/r2rml/>
- B. Motik, B. Cuenca Grau, I. Horrocks, Z. Wu, A. Fokoue, C. Lutz. *OWL 2 Web Ontology Language: Profiles (Second Edition).* W3C Recommendation, 2012. <https://www.w3.org/TR/owl2-profiles/>
- P. Gearon, A. Passant, A. Polleres. *SPARQL 1.1 Update.* W3C Recommendation, 2013. <https://www.w3.org/TR/sparql11-update/>
- L. Sauermann, R. Cyganiak. *Cool URIs for the Semantic Web.* W3C Interest Group Note, 2008. <https://www.w3.org/TR/cooluris/>

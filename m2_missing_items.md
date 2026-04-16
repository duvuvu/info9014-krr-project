# Milestone 2 — Missing Items

Two hard requirements from the project statement are not yet in `cineexplorer_ontology.ttl`.

---

## 1. Co-author annotations on the ontology header

The spec says: *"All involved students must be included as authors using ontology annotations."*

The ontology header currently only has `rdfs:label` and `rdfs:comment`. Need to add `dc:creator` (one per author) plus `owl:versionInfo` and `dc:date`.

Required prefixes to add at the top of the file:
```turtle
@prefix dc:   <http://purl.org/dc/elements/1.1/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
```

Required annotations to add to the `<https://example.org/cineexplorer/ontology>` block:
```turtle
    dc:creator "Dawid Raczkowski" ;
    dc:creator "Hoang Linh Bui" ;
    dc:creator "Duy Vu Dinh" ;
    owl:versionInfo "v5" ;
    dc:date "2025"^^xsd:gYear ;
    dc:description "CineExplorer ontology for the INFO9014 project at ULiège."@en ;
```

---

## 2. Sample ontology individuals (ABox)

The spec says: *"One or more ontologies featuring … all concepts, relations, and ontology individuals."*

The current file has zero `owl:NamedIndividual` instances. Lab 2 showed the pattern of a separate ABox file linked via `owl:imports`.

Recommended approach: create `cineexplorer_individuals.ttl` that imports the ontology and declares a small set of individuals covering all classes, e.g.:

- 2–3 `:Film` individuals (e.g., based on real tconst values from the CSV)
- 1–2 `:Series` individuals
- 1 `:Episode` individual (with `partOfSeries` pointing to a Series individual)
- 3–4 `:Person` individuals (typed as `:Actor`, `:Director`, etc.)
- 1–2 `:Genre` individuals (e.g., Drama, Comedy)
- 2–3 `:Participation` individuals (linking a Person to a CreativeWork)

These can be drawn directly from the first rows of the CSV files so they are consistent with the real data.

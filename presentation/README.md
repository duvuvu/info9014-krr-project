# CineExplorer — Presentation Speaker Script

INFO9014 — Knowledge Representation & Reasoning, ULiège
Team: Dawid Raczkowski (s200735), Hoang Linh Bui (s2503303), Duy Vu Dinh (s2401627)

Target duration: **~20 minutes**, 22 slides.

---

## Overview

| Block | Slides | Time |
|---|---|---|
| Intro & data | 1–5 | ~4 min |
| Ontology | 6–9 | ~4.5 min |
| Mapping & deploy | 10–13 | ~3.5 min |
| SPARQL trio (Q11, Q7, Q12) | 14–16 | ~4 min |
| Demonstrator | 17–19 | ~3 min |
| Live demo + close | 20–22 | ~4 min |
| **Total** | | **~20–22 min** |

Pauses are marked with `…`. Hand-offs between presenters are marked **[hand off to NAME]**.

---

## Slide 1 — Title (~25 s)

> "Good morning everyone. We are presenting **CineExplorer** — a knowledge graph for filmography, built on the IMDb dataset. I'm Duy Vu Dinh, and with me are Hoang Linh Bui and Dawid Raczkowski. This is our final project for INFO9014, Knowledge Representation and Reasoning, with Professor Debruyne. We will walk you through the four milestones of the project — database, ontology, mapping, and deployment — and finish with a live demo. The talk takes about twenty minutes."

---

## Slide 2 — Problem & Goal (~45 s)

> "Let's start with the problem. IMDb publishes its catalogue as a set of flat TSV files. You can load them into a relational database and run joins, but you cannot *follow links* across entities, you cannot *federate* with other datasets, and you cannot *validate* the data semantically.
>
> Our goal was to turn that relational slice into a *queryable, linkable knowledge graph* — modelled in OWL, mapped with R2RML, deployed in Apache Fuseki, and exposed through a Linked Data browser.
>
> The project ran across four milestones, shown here. Each built on the previous one. By the end, we can ask a single SPARQL query like *who collaborated with Kevin Bacon, and what is their Wikidata birth date* — which is exactly what we will demonstrate live at the end."

---

## Slide 3 — Dataset: IMDb sample (~60 s)

> "Our source is the IMDb non-commercial dump — seven TSV files covering titles, principals, crew, names, akas, episodes, and ratings. The full IMDb is around ten million titles, which is too much for a teaching project, so we sliced it: **top-N by number of votes per title type**. That gives us the most-watched works in each category — five thousand titles in total.
>
> After mapping, the deployed knowledge graph contains around **1.6 million triples**, covering **5,000 titles** and **38,000 persons**, in a 118-megabyte Turtle file. The title types we kept are movies, TV series, mini-series, pilots, and episodes — five types out of the dozen IMDb defines. We will come back to the *unmapped* types later — they show up in our SHACL validation as an interesting data-quality finding."

---

## Slide 4 — ERD (~60 s)

> "This is the entity-relationship diagram of our source database. Two driving keys run through everything: `TITLE_ID`, which is IMDb's `tconst` — those `tt`-prefixed identifiers — and `TALENT_ID`, which is `nconst`, the `nm`-prefixed person IDs. These keys survive every layer of our pipeline. They end up embedded inside the IRIs of the deployed graph, and that turns out to be useful for federation with Wikidata, as we'll see later.
>
> The diagram has two interesting axes connecting persons to titles. The **per-credit axis** goes through `title_principal` and `principal_role` — that's the data telling us *in this specific film, this specific person played this specific role*. The **career axis** goes through `talent_title` and `talent_role` — that's the higher-level claim that a person *is known for* a work, or *is a director by profession*. Keeping both axes was a deliberate choice, and our SHACL validation later in the talk surfaces what that choice costs."

---

## Slide 5 — Relational model (~45 s)

> "The schema groups into four blocks. Core entities are `title` and `talent`. Credits go through `title_principal` and `principal_role`. Structure — the series-to-episode relationship and the genre links — goes through `title_episode` and `title_genre`. And we have aliases and career data in `title_aka`, `talent_title`, and `talent_role`.
>
> The schema is in third normal form with foreign keys enforced on InnoDB. We host it in MySQL 8 running in Docker on port 3307, with phpMyAdmin on port 8080 for inspection. Nothing exotic — it's a clean relational source, deliberately so, because R2RML works best against a well-normalised schema."

---

## Slide 6 — Ontology overview (~75 s)

> "Now to the ontology — milestone two. Our namespace is `ce`, short for CineExplorer. Two main class hierarchies. On the work side: `CreativeWork` splits into `Film`, `Series`, and `Episode` — these three are **disjoint**, because no IMDb title is simultaneously a film and a series. On the person side: `Person` splits into `Actor`, `Director`, `Writer`, `Editor`, and `Composer` — and these are deliberately **not disjoint**, because the same person can be both an actor and a director. Clint Eastwood would be the obvious example.
>
> The interesting design decision is the `Participation` class. A credit is naturally a *ternary* relationship — a person, in a work, in a specific role. OWL has no native n-ary properties, so we **reify** the participation: each credit becomes its own instance, with `playedBy`, `participatesIn`, and `participationRole` links. This lets us attach things like character names and ordering to the credit itself, without polluting the binary property graph.
>
> The ontology was authored in Protégé and reasoned with HermiT to verify consistency."

---

## Slide 7 — Ontology key properties (~60 s)

> "Almost every object property comes with an explicit inverse. `actedIn` pairs with `hasActor`, `directed` with `directedBy`, and so on for writers, editors, and composers. The pair we'll come back to is `workedFor` and `employed` — these generalise across all role types. A person `workedFor` a creative work, and the work `employed` the person.
>
> We also have structural properties — `partOfSeries` and `hasEpisode` for the series-to-episode link, and `participatesIn` from the reified participations to the work.
>
> The property to pay attention to is `workedWith`. Declared **symmetric** — if A worked with B, then B worked with A. The natural definition is *two persons sharing a creative work*. We *wanted* to define this with a property chain in the ontology, but as you'll see on the next slide, that ran into the OWL 2 QL profile boundary."

---

## Slide 8 — OWL profiles: the choice (~75 s)

> "Two slides on the profile choice, because it ends up shaping the whole SPARQL story.
>
> OWL 2 ships with three sub-profiles plus the full DL language. Each is engineered for a *different* reasoning task, with a *different* complexity guarantee.
>
> **EL** is for classification of huge taxonomies — SNOMED CT, the Gene Ontology — polynomial time. **QL** is for query answering via first-order rewriting — that's the OBDA story, Ontop, Stardog QL mode — and its data complexity is LogSpace, the same class as plain SQL. **RL** is for rule-based forward chaining. And full **DL** is for editor-time reasoning, which is doubly-exponential in the worst case — fine for Protégé, unusable at query time.
>
> We picked **QL**, and for one reason: we are deploying this graph to be *queried*, not classified. The QL guarantee is that any conjunctive query rewrites to a finite union of conjunctive queries over the data, with **no reasoner in the loop at query time**. Fuseki alone is sufficient. That is the right trade-off for a deployed KG.
>
> What QL still gives us is the entire core of our ontology — class hierarchy, inverse properties, domain and range, disjointness, RHS existentials. What it takes away is on the next slide."

---

## Slide 9 — What OWL 2 QL forced us to drop (~60 s)

> "The QL profile is defined by what it forbids — the constructs that would break first-order rewriting. Property chains, left-hand-side existentials, functional and transitive properties, `hasKey`, `hasSelf`, and a few others.
>
> One of these directly hits us. We wanted to define `workedWith` with a property chain — `workedFor` composed with the inverse of `workedFor`. Two persons co-occurring on a shared work. That is **exactly** the schematic pattern QL was designed to exclude — two atoms sharing a variable on the left-hand side, unbounded over the data.
>
> SWRL doesn't save us either, because SWRL is outside *every* OWL 2 profile, not just QL.
>
> So the axiom has to live somewhere we control execution. That somewhere is SPARQL. We recover `workedWith` as a `CONSTRUCT` query — Q11, coming up in a few slides. It is not a workaround. It is the architecturally correct response to the profile choice."

---

## Slide 10 — R2RML mapping: concept (~45 s)

> "Milestone three: the mapping. We use **R2RML**, the W3C standard for turning relational data into RDF.
>
> The mental model is three pieces per mapping rule. A *logical table* — typically a SQL query — supplies the rows. A *subject map* turns each row into an IRI, using a template like `data/title/{TITLE_ID}`. And one or more *predicate-object maps* generate the predicates and literal or IRI values.
>
> We run it in **materialised mode**: the R2RML processor reads from MySQL once, writes a Turtle file, and the deployment then serves that file. No live JDBC connection at query time. The command is one line — `java -jar r2rml.jar mapping.properties`."

---

## Slide 11 — Mapping: one worked example (~60 s)

> "Here's a real triple map from our mapping file — the one for titles classified as movies. The logical table is a SQL query selecting four columns from the `title` table. The subject map builds an IRI from the `TITLE_ID` and asserts the class `ce:Film`. Then three predicate-object maps generate the title, the average rating, and the vote count.
>
> One row of SQL gives us four triples — one type assertion plus three literal-valued properties. The whole mapping file has around twenty triple maps like this one, covering titles, persons, genres, episodes, principals, and the reified participations. The rest of the slides assume this layer is done — what you'll see from here on is the *output* of running this mapping."

---

## Slide 12 — KG result (~45 s)

> "Running the mapping against the full database produces **1.6 million triples**, in a 118-megabyte Turtle file. That covers 5,000 creative works, 38,000 persons, the genres, and the reified participations.
>
> Here on the right is a snippet for one person — Kevin Bacon, who we'll use repeatedly in the demo. You can see his type assertions, his name, his birth year, the works he's known for, and his `actedIn` edges. This is now the input to milestone four — deployment and querying."

---

## Slide 13 — Deployment architecture (~75 s)

> "Milestone four. Two independent Docker Compose stacks. The first is the source database — MySQL and phpMyAdmin — which is only needed at *mapping time*. Once the Turtle file is materialised, the database can be shut down.
>
> The second stack is the deployment: **Apache Fuseki** on port 3030, and **Brwsr** on port 5000. Fuseki is the SPARQL endpoint and TDB2 triple store. Brwsr is a thin Flask app that turns Linked Data IRIs into clickable HTML — when a browser asks for `/data/person/nm0000102`, it issues a `DESCRIBE` query to Fuseki and renders the result. With content negotiation: HTML to browsers, Turtle or JSON-LD to API clients.
>
> The two stacks talk through a shared Docker network — Brwsr addresses Fuseki internally as `http://fuseki:3030`. Loading the KG is a one-time `curl` to Fuseki's Graph Store endpoint.
>
> This architecture operationalises the W3C Linked Data principles — every IRI we mint can be dereferenced to a useful description, with links to other IRIs."

---

## Slide 14 — SPARQL Q11: CONSTRUCT `workedWith` (~90 s)

> "Now to the queries. We selected three out of the ten we wrote, each highlighting a different SPARQL technique.
>
> Q11 is the *payoff* of the OWL 2 QL discussion. Remember from Slide 9, we wanted `workedWith` as a property chain in the TBox, and QL forbade it. Here is the SPARQL `CONSTRUCT` that recovers it.
>
> The pattern is seven lines. Two persons, each `workedFor` the same work, with a filter to drop self-loops. The `CONSTRUCT` template emits `workedWith` triples. Notice we don't need to add symmetry explicitly — `?p1` and `?p2` are unordered variables, so every pair gets emitted in both directions automatically.
>
> Running this against the deployed KG produces **1.68 million triples** — symmetric collaboration edges across all 38,000 persons. That is **1.04 times the size of the source graph** for just this one derived relation. The top collaborator has over two thousand co-workers — a power-law signature typical of collaboration networks.
>
> This is the empirical justification for the QL designers' decision to forbid property chains. If we'd put this axiom in the TBox and materialised it, we'd be doubling the storage footprint. By keeping it in SPARQL, we get it **on demand**, with no staleness, freely composable into other queries — including Q12 on the next slide."

---

## Slide 15 — SPARQL Q7: Federation to Wikidata (~75 s)

> "Q7 is federation. SPARQL 1.1's `SERVICE` keyword lets us issue a sub-query against a remote endpoint and join the results with our local pattern.
>
> Here's how we use it. We pick ten persons from the Les Misérables cast. For each, we extract the `nconst` from the IRI using `BIND` and `REPLACE` — basically a string strip. Then we send that `nconst` to **Wikidata's SPARQL endpoint** inside the `SERVICE` block. Wikidata exposes the IMDb person ID through property `P345`. So the join is over a *literal string*, not a `owl:sameAs` link.
>
> This is important. We don't need to materialise any cross-dataset identity statements. The IRI structure of our KG — embedding `nconst` directly — gives us federation **for free**. The `OPTIONAL` blocks then pull in the Wikidata birth date and the English label.
>
> The result is ten cast members linked to their Wikidata items with birth dates attached. This also closes one of the open items from our M3 self-review — we had flagged `sameAsExternal` as needing further work, and Q7 is the resolution: federation at query time beats materialised links."

---

## Slide 16 — SPARQL Q12: Pairwise Bacon distance (~75 s)

> "Q12 uses property paths to compute Bacon distances.
>
> The query itself is an `ASK` with a bounded property path: `workedFor` followed by its inverse, repeated exactly *k* times. Here we hard-code Kevin Bacon as source and Tom Hanks as target, and ask: is there a path of length one between them? The answer is `true`, in 0.2 seconds, because they share Apollo 13 in 1995.
>
> The pedagogical point of this slide is what `{k,k}` really does. SPARQL 1.1's property paths express **reachability, not distance**. There is no built-in shortest-path operator. So to compute the Bacon distance, you have to **iterate** — try k equals one, if false try k equals two, and so on. The smallest k for which the ASK returns true *is* the Bacon distance.
>
> One important caveat: the `{k,k}` exact-length quantifier is an **Apache Jena extension**. It was in the early SPARQL 1.1 drafts and got dropped from the final REC. Fuseki accepts it. On a strict-1.1 engine, you'd have to write out the path concatenation by hand — for k equals two, that's `workedFor/employed/workedFor/employed`. The extension just makes the iteration cleaner."

---

## Slide 17 — Non-trivial demonstrator: overview (~30 s)

**[hand off to Hoang Linh — the demonstrator slides]**

> "We built two complementary demos to showcase non-trivial reasoning. The first is a **Bacon-number coverage analysis** — what reachability looks like at scale. The second is **SHACL validation** — what data quality looks like at scale, with eight shapes and three validation runs.
>
> These are the two questions every KG owner asks: *what can I infer about my data*, and *is my data even self-consistent*."

---

## Slide 18 — Demonstrator part 1: Bacon coverage (~60 s)

> "First, the coverage analysis. For each starting person, we count how many other persons are reachable at distance one, two, and three over the `workedFor`/`employed` path.
>
> Starting from Kevin Bacon: 403 collaborators at one hop — that's just over one percent of all persons in the graph. At two hops, it jumps to over eighteen thousand — nearly half the graph. At three hops, **ninety-two percent of all persons are reachable**.
>
> Russell Crowe gives similar numbers — 558 at one hop, fifty-six percent at two hops.
>
> This is the classic *small-world* signature. Most persons are within three handshakes of any well-connected actor. The jump from one to two hops is the most dramatic — that's preferential attachment at work, where well-connected hubs amplify reach exponentially. This is exactly the kind of insight you can't get from a relational query — it needs the graph structure plus property-path reasoning."

---

## Slide 19 — Demonstrator part 2: SHACL validation (~90 s)

> "Second demo: SHACL validation. We wrote eight shapes — five **core shapes** with property constraints, and three **SHACL-SPARQL shapes** for cross-property and cross-resource invariants.
>
> We ran validation three times with progressively more reasoning, and the results tell a textbook story.
>
> **Run one**: no inference. We got **a hundred and six thousand violations**. All from the `ParticipationShape` — it says `participatesIn` must point to a CreativeWork, but no title is *asserted* with type `CreativeWork` in the graph. Every title is typed `Film`, `Series`, or `Episode` directly. SHACL without inference doesn't know about subclasses, so it flags every edge as broken.
>
> **Run two**: we add RDFS inference. Violations drop from 106,000 to **seventy-five**. This is the textbook OWA/CWA contrast: same shapes, same data, the only difference is whether the validator was told about subclass entailment. The remaining 75 violations are real — 25 titles whose `titleType` isn't covered by our mapping. The mapping handles movies, series, mini-series, pilots, and episodes; it misses `short`, `tvMovie`, `tvSpecial`, `video`, and `videoGame`. Those titles get referenced but never typed.
>
> **Run three**: we add the SPARQL shapes. Two interesting findings. The pre-birth-credit shape catches **32 real anomalies** — IMDb birth-year typos and re-release credits. And the director-consistency shape flags **5,459 persons** typed as Director from the career axis with no per-credit Participation. That's the dual-axis design we discussed on the ERD slide, made *visible* and *quantifiable*. Not a bug — a quantification of an architectural choice."

---

## Slide 20 — Live demo (~3 min, off-script)

**[switch to live screen-share — presenter not reading from notes]**

Suggested narration as you click:

> "Let me show you this live. First, the Fuseki query interface…
>
> *[paste Q7]* …running Q7 against Wikidata — and here are the ten cast members with their Wikidata items and birth dates joined in real time.
>
> Next, the Brwsr Linked Data view. If I navigate to `data/person/nm0000102` — that's Kevin Bacon — I get a dereferenceable HTML page. I can click on any `actedIn` edge…
>
> *[click into a film, click on another actor]* …and follow links across the graph. This is what *real* linked data looks like.
>
> Finally, Q12. I'll let the audience pick a person — *[take suggestion]* — and we'll compute their Bacon distance live."

---

## Slide 21 — Reflections & limitations (~45 s)

**[hand back to original presenter]**

> "A few honest reflections. We accepted three trade-offs.
>
> The QL profile choice pushed `workedWith` out of the TBox into SPARQL. That's the right trade for query performance, but it means readers of the ontology don't see the axiom — only readers of Q11 do.
>
> The `{k,k}` syntax in Q12 is a Jena extension, not strict SPARQL 1.1. A different engine would need rewriting.
>
> The Wikidata federation depends on remote uptime — the live demo has a fallback.
>
> Two known open items: 25 titles have unmapped `titleType`s, and the director dual-axis is deliberately documented rather than fixed. Both are surfaced by SHACL, which we think is the right outcome — the validator should make the design visible."

---

## Slide 22 — Conclusion + Q&A (~45 s)

> "To summarise. Milestone one: an IMDb sample loaded into MySQL — 5,000 titles, 38,000 persons. Milestone two: an OWL 2 QL ontology, profile-checked and consistency-verified. Milestone three: a 1.6-million-triple knowledge graph generated by R2RML. Milestone four: Fuseki and Brwsr deployed; ten SPARQL queries written, three highlighted today; and a non-trivial demonstrator combining Bacon-number analysis with SHACL validation.
>
> One forward-looking line: the same architecture scales to the full IMDb — around ten million titles — without ontology changes. The bottleneck becomes mapping run time, not modelling.
>
> Thank you. We're happy to take questions."

---

## Backup — Q&A anticipated questions

| Question | Short answer |
|---|---|
| Why not OWL 2 DL with the property chain? | Loses LogSpace data complexity, loses OBDA compatibility, materialisation cost is the same anyway. |
| Is `workedWith` transitive? | No — symmetric only. Co-workers of co-workers ≠ co-workers. That's the Bacon-number question. |
| Why CONSTRUCT instead of INSERT for Q11? | On-demand, no staleness, no persistent 1.04× storage cost. |
| Why federation instead of materialised `sameAs`? | Wikidata exposes IMDb IDs natively (`wdt:P345`); IRI structure gives us the join for free. |
| What happens if Wikidata is down during the demo? | Q11 is a purely local fallback — full graph CONSTRUCT, no remote dependency. |
| Why both per-credit and career axes for persons? | Per-credit captures the role in a specific work; career captures `primaryProfession`. SHACL surfaces the divergence. |
| Can this scale to full IMDb? | Architecture is unchanged; bottleneck is R2RML run time, not modelling. |

---

## Timing aids

- Run-long cuts: shorten Slide 5 to ~20 s, drop Run 3 detail from Slide 19, trim demo to two clicks.
- Run-short fillers: expand Slide 4 ERD discussion, add a second person to Slide 18 coverage table.
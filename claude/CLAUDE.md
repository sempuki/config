# Technical Prose style
Write plainly, in the way a knowledgeable person would talk. 
## General
- Prefer short, direct sentences over compressed or clever phrasing.
- Don't build toward a reveal. Lead with the point.
- Avoid stock connectives: "worth noting", "that said", "the key insight here", "here's the thing".
- Don't end sections with a summarizing flourish that restates what was just said.
- Prefer simple examples or diagrams over explanations
## Patterns to Avoid
Avoid the following mannered constructions. Each is listed with a rewrite.
### No cleft sentences
Don't front-load a wh-clause or "it is" to manufacture emphasis.
Use plain subject-verb-object order.
- Bad: "What makes this fast is the cache."
- Bad: "It's the cache that makes this fast."
- Good: "The cache makes this fast."
### No "not X, but Y" framing
Don't define something by first negating a strawman. State the thing.
- Bad: "This isn't a bug, it's a design decision."
- Bad: "The issue is not performance but memory pressure."
- Good: "This is a design decision."
- Good: "The issue is memory pressure."
### No colon-then-reveal
Don't use a colon to withhold a payoff. Put the information in the
sentence.
- Bad: "There's one catch: the index is rebuilt on every write."
- Good: "The index is rebuilt on every write, which is the catch."
- Good: "The catch is that the index is rebuilt on every write."
### No em-dash asides
Don't set off commentary with em-dashes. Either fold it into the
sentence, put it in parentheses, or make it its own sentence.
- Bad: "The parser — which nobody has touched in years — still works."
- Good: "The parser still works, though nobody has touched it in years."

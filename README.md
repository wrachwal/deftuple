# deftuple

## Record-like API for tuples

This application provides `TUPLE.deftuple/2` and `TUPLE.deftuplep/2`
macros similar to `Record.defrecord/3` and `Record.defrecordp/3`
macros. The only difference is that `TUPLE.deftuple/2` and
`TUPLE.deftuplep/2` do not introduce a tag (atom) as the first
element in a resulting tuple data.

The advantage of having alternate API (featured with named tuple
elements) when comparing to literal syntax of tuples becomes apparent
when a tuple has more elements and/or its arity or structure changes
over time in a complex code.

Defining such "tag-less records" may seem odd, but it has at least
one notable use case (you may find others): in ETS table to store
tuples of different shapes where the key typically consists of
a fixed tag (to identify shape) and variable part(s) (to
differentiate instances). In such heterogenic ETS tables there's
also a place for use of records when singular instances are
appropriate (e.g. to hold "global" counters).

## Implementation Notes

The code that forms TUPLE module has been extracted from
Tuple module on [deftuple](https://github.com/wrachwal/elixir/commits/deftuple)
branch of (forked) Elixir repo.

API was proposed on [elixir-core](https://groups.google.com/d/msg/elixir-lang-core/COuXyaL5OVQ/8PiF-HkkAwAJ)
mailing list, but the proposal, at least for now, was rejected.

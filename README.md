# Fedi

ActivityStreams, and eventually ActivityPub, in Elixir.

Inspired by https://github.com/go-fed/activity

Property type modules for the ActivityStreams ontology are
generated using `mix ontology.gen`.

Value type modules are hand-coded for now.

See https://github.com/go-fed/activity/tree/master/astool
for the details on how this worked in go. In this project
we do a simpler, non-type-checked parsing of the ontology
.jsonld file that go-fed curated from the ActivityStreams
vocabulary and specification.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `fedi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fedi, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/fedi>.

## TODO

- Limit the ranges and domains of properties and types
  according to the .jsonld ontology.
- Add builder methods (new, clear, set, get, etc) to
  restrict programmatic access to valid ranges and
  domains.
- Get the fedi_server example application to pass
  basic tests as an ActivityPub C2S server.

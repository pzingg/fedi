# Fedi

ActivityStreams and ActivityPub in Elixir.

The main part of the library code is a literal translation
from the [go-fed](https://github.com/go-fed/activity) package
written in Go.

Property modules for the ActivityStreams ontology are
generated using `mix ontology.gen`.

Type value modules are hand-coded for now.

See https://github.com/go-fed/activity/tree/master/astool
for the details on how this worked in go-fed. In this project
we do a simpler, non-type-checked parsing of the ontology
.jsonld file that go-fed curated from the ActivityStreams
vocabulary and specification.

## Example application

See the README for the `fedi_server` example application, in the
"examples" folder, for a simple Phoenix web app that uses this library
to implement basic ActivityPub handling.

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

Top level documentation

- Provide clear instructions for how to hook the library up to a Phoenix
  application.

Ontology generation tool

- Document the `ontology.gen` mix task.
- Output generated modules for ActivityStream types (currently these are
  hand-coded). Refactor out the `Meta` modules for types to reduce complexity.

Other enhancements and bug fixes

- Limit the ranges and domains of properties and types according to
  the .jsonld ontology.
- Add builder methods (new, clear, set, get, etc) to restrict programmatic
  access to valid ranges and domains.
- `Fedi.Application.endpoint_url/0` should fetch the external endpoint
  URL from the implementing application, not the other way around.
  Maybe this can be done with a `__using__` macro, set up in the
  implementing application.

More tests to increase code coverage.

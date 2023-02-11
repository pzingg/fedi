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

## Details

See [IMPLMENTATION.md](IMPLEMENTATION.md) for test suite coverage,
in order to assess the conformance of the library and example application to the
ActivityPub specification for both the Social API (client-to-server
interactions) and the Federated Protocol (server-to-server interactions).

The example application uses a user token stored in a session cookie,
possibly fetched from a persistent "remember_me" cookie,
to authenticate activities posted to the outbox for the Social API,
following the standard methods of `phx.gen.auth`.

For the Federated protocol, the application creates HTTP signatures on
outgoing activities posted to remote inboxes, and validates HTTP
signatures for activities arriving at local inboxes.

There is also support for 'webfinger', 'host-meta' and 'nodeinfo'
endpoints in the example application.

The application supports these collections:

- `:object/likes`
- `:object/shares`
- `:account/inbox`
- `:account/outbox`
- `:account/following`
- `:account/followers`
- `:account/collections/liked`
- `:account/collections/featured`

as well as ad-hoc account collections.

The example application also has some rudimentary "web" support
a la Mastodon. It supports only `Note` objects posted in Markdown
format, but is able to parse out hyperlinks, mentions and hashtags,
and can display Note content as HTML with links for these.

There are also basic stubs for the Mastodon timelines "Home", "Local" and
"Federated".

The routes for these "web" urls are:

- `/web/timelines/home`
- `/web/timelines/local`
- `/web/timelines/federated`
- `/web/directory`
- `/web/accounts/:account_id`
- `/web/statuses/:object_id`

## TODO

Add more Mastodon-ish features that are not in the AP spec if they are
easy to implement:

- shares
- replies
- conversations

Top level documentation

- Provide clear instructions for how to hook the library up to a Phoenix
  application.

Ontology generation tool

- Document the `ontology.gen` mix task.

Other enhancements and bug fixes

- Limit the ranges and domains of properties and types according to
  the .jsonld ontology.
- Add builder methods (new, clear, set, get, etc) to restrict programmatic
  access to valid ranges and domains.
- `Fedi.Application.endpoint_url/0` should fetch the external endpoint
  URL from the implementing application, not the other way around.
  Maybe this can be done with a `__using__` macro, set up in the
  implementing application.

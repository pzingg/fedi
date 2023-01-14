# FediServer

A simplified, server-only implmentation of an ActivityPub web application,
using the `fedi` Elixir library. No user interface is provided, but
should perform as expected by using, for example, curl command-line
invocations to the inbox, outbox, etc. endpoints.

Some basic controller integration tests are provided.

Exposes endpoints for user inbox (GET and POST), outbox (GET and POST),
fetching objects and activities, and sending and receiving
federated HTTP requests that use
[HTTP signatures](https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures).

Also exposes "well-known" instance-level endpoints for
[WebFinger](https://www.rfc-editor.org/rfc/rfc7033.html),
[host-meta](https://datatracker.ietf.org/doc/html/rfc6415), and
[nodeinfo](http://nodeinfo.diaspora.software/schema.html).

## Details and caveats

The main external dependency is the
[http_signatures](https://git.pleroma.social/pleroma/elixir-libraries/http_signatures)
Hex package, part of the Pleroma project. Other code from Pleroma
has been slightly simplified and packaged in the modules
`FediServer.HTTPClient`, `FediServerWeb.XMLBuilder`,
`FediServerWeb.WebFinger` and `FediServerWeb.WellKnownController`.

The [sweet_xml](https://github.com/kbrw/sweet_xml) package
(also used by Pleroma) is used to build and parse XML documents.

The `fedi` library is included as a dependency in `mix.exs`. It
is hooked in by a plug (see `router.ex`) that puts a configured
`Fedi.ActivityPub.SideEffectActor` into the HTTP connection.

Controllers (see `inbox_controller.ex` and `outbox_controller.ex`)
pull the Actor out of the connection to process the GET and
POST requests.

No user authentication or authorization is performed.

Further testing in a real-world federating environment (sending to and
receiving from actors on other servers, say Pleroma or Mastodon servers),
is needed to provide full code coverage. Currently these have only been
tested using `Tesla.Mock` responses in the test Mix environment.

The external URL for the application must currently be specified in
the `fedi` application environment, and should agree with the application's
[endpoint configuration](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#module-endpoint-configuration).

## Installation

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

## TODO

Add `min_id`, `max_id`, and `page` query params for inbox and outbox
controller "GET" handlers to control paged results.

Modify database schema, add logic and controllers to support 'liked',
'followers', and 'following' collections.

# FediServer

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

## FediServer application

1. Create delegate with callbacks

2. Create an `Actor` with C2S and/or S2S protocols enabled

3. Hook the `Actor` into the router, by creating
an OutboxController and an InboxController, and
connecting routes in router.ex

```golang
// The application's actor
var actor pub.Actor
var outboxHandler http.HandlerFunc = func(w http.ResponseWriter, r *http.Request) {
  c := context.Background()
  // Populate c with request-specific information
  if handled, err := actor.PostOutbox(c, w, r); err != nil {
    // Write to w
    return
  } else if handled {
    return
  } else if handled, err = actor.GetOutbox(c, w, r); err != nil {
    // Write to w
    return
  } else if handled {
    return
  }
  // else:
  //
  // Handle non-ActivityPub request, such as serving a webpage.
}
var inboxHandler http.HandlerFunc = func(w http.ResponseWriter, r *http.Request) {
  c := context.Background()
  // Populate c with request-specific information
  if handled, err := actor.PostInbox(c, w, r); err != nil {
    // Write to w
    return
  } else if handled {
    return
  } else if handled, err = actor.GetInbox(c, w, r); err != nil {
    // Write to w
    return
  } else if handled {
    return
  }
  // else:
  //
  // Handle non-ActivityPub request, such as serving a webpage.
}
// Add the handlers to a HTTP server
serveMux := http.NewServeMux()
serveMux.HandleFunc("/actor/outbox", outboxHandler)
serveMux.HandleFunc("/actor/inbox", inboxHandler)
var server http.Server
server.Handler = serveMux
```

To serve ActivityStreams data:

```golang
myHander := pub.NewActivityStreamsHandler(myDatabase, myClock)
var activityStreamsHandler http.HandlerFunc = func(w http.ResponseWriter, r *http.Request) {
  c := context.Background()
  // Populate c with request-specific information
  if handled, err := myHandler(c, w, r); err != nil {
    // Write to w
    return
  } else if handled {
    return
  }
  // else:
  //
  // Handle non-ActivityPub request, such as serving a webpage.
}
serveMux.HandleFunc("/some/data/like/a/note", activityStreamsHandler)
```

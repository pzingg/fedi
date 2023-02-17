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

Status URLS

- `id` - "https://mastodon.cloud/users/pzingg/statuses/109365863602876549"
- `url` - "https://mastodon.cloud/@pzingg/109365863602876549"

The application supports these singleton items:

- `/@:nickname` (HTML shows user profile and timeline. JSON shows user profile only.)
- `/@:nickname/:object_id`
- `/users/:nickname` (JSON only - user profile only)
- `/users/:nickname/statuses/:object_id`

The application supports these collections:

- `/@:nickname/:object_id/likes`
- `/@:nickname/:object_id/shares`
- `/@:nickname/:object_id/reblogs`
- `/@:nickname/:object_id/favourites`
- `/@:nickname/featured`
- `/@:nickname/followers`
- `/@:nickname/following`
- `/@:nickname/liked`
- `/@:nickname/media` (HTML only - media)
- `/@:nickname/with_replies` (HTML only - posts and replies)
- `/@:nickname` (HTML only - posts)
- `/inbox`
- `/users/:nickname/collections/featured`
- `/users/:nickname/collections/liked`
- `/users/:nickname/followers`
- `/users/:nickname/following`
- `/users/:nickname/inbox`
- `/users/:nickname/media` (media)
- `/users/:nickname/outbox`
- `/users/:nickname/statuses/:object_id/likes`
- `/users/:nickname/statuses/:object_id/shares`
- `/users/:nickname/statuses/:object_id/reblogs`
- `/users/:nickname/statuses/:object_id/favourites`
- `/users/:nickname/with_replies` (posts and replies)
- `/users/:nickname` (JSON gives user profile. HTML redirects to `/@:nickname` - posts)

as well as ad-hoc account collections.

The example application also has some rudimentary "web" support
a la Mastodon. It supports only `Note` objects posted in Markdown
format, but is able to parse out hyperlinks, mentions and hashtags,
and can display Note content as HTML with links for these.

There are also basic stubs for the Mastodon timelines "Home", "Local" and
"Federated".

The routes for these "web" urls are:

- `/web/accounts/:nickname`
- `/web/bookmarks`
- `/web/directory`
- `/web/favorites`
- `/web/statuses/:object_id`
- `/web/timelines/direct`
- `/web/timelines/federated`
- `/web/timelines/home`
- `/web/timelines/local`

## Mastodon-equivalent activities

Add more Mastodon-ish features that are not in the AP spec if they are
easy to implement.

### Post

```
%{
  "type" => "Create",
  "to" => "as:Public",
  "cc" => [
    "https://example.com/users/me/followers",
    "https://other.example/users/mentioned"
  ],
  "actor" => "https://example.com/users/me",
  "object" => %{
    "type" => "Note",
    "id" => "https://example.com/users/original/objects/OBJECTID",
    "content" => "**My Markdown post** mentioning @mentioned@other.example",
    "attributedTo" => "https://example.com/users/me",
    "tag" => [
      %{
        "type" => "Mention",
        "href" => "https://other.example/users/mentioned",
        "name" => "@mentioned@other.example"
      }
    ]
  }
}
```

### Direct message

Must not have any "as:Public" or follower audience.

```
%{
  "type" => "Create",
  "to" => "https://example.com/users/someone",
  "actor" => "https://example.com/users/me",
  "object" => %{
    "type" => "Note",
    "id" => "https://example.com/users/original/objects/OBJECTID",
    "content" => "**My Markdown message**",
    "attributedTo" => "https://example.com/users/me"
  }
}
```

### Reply

```
%{
  "type" => "Create",
  "to" => [
    "https://example.com/users/original",
    "https://example.com/users/me/followers"
  ],
  "cc" =>  [
    "as:Public",
    "https://other.example/users/mentioned"
  ],
  "actor" => "https://example.com/users/me",
  "object" => %{
    "type" => "Note",
    "content" => "@original@example.com **My Markdown reply**",
    "attributedTo" => "https://example.com/users/me",
    "inReplyTo" => "https://example.com/users/original/objects/OBJECTID",
    "tag" => [
      %{
        "type" => "Mention",
        "href" => "https://example.com/users/original",
        "name" => "@original@example.com"
      }
    ]
  }
}
```

### Boost

```
%{
  "type" => "Announce",
  "to" => "as:Public",
  "cc" => [
    "https://example.com/users/me/followers",
    "https://other.example/users/mentioned"
  ],
  "actor" => "https://example.com/users/me",
  "object" => "https://example.com/users/original/objects/OBJECTID"
}
```

### Favorite

Favorites can be shared or not?

```
%{
  "type" => "Add",
  "to" => "https://example.com/users/me",
  "actor" => "https://example.com/users/me",
  "object" => "https://example.com/users/original/objects/OBJECTID",
  "target" => "https://example.com/users/me/favorites"
}
```

### Bookmark

Bookmarks can be shared or not?

```
%{
  "type" => "Add",
  "to" => "https://example.com/users/me",
  "actor" => "https://example.com/users/me",
  "object" => "https://example.com/users/original/objects/OBJECTID",
  "target" => "https://example.com/users/me/bookmarks"
}
```

## TODO

### Support additional Mastodon features:

Muting hides the user from your view:

- You won’t see the user in your home feed
- You won’t see other people boosting the user
- You won’t see other people mentioning the user
- You won’t see the user in public timelines
- Can have an expiration time

Blocking hides a user from your view:

- You won’t see the user in your home feed
- You won’t see other people boosting the user
- You won’t see other people mentioning the user
- You won’t see the user in public timelines
- You won’t see notifications from that user

Additionally, on the blocked user’s side:

- The user is forced to unfollow you
- The user cannot follow you
- The user won’t see other people’s boosts of you
- The user won’t see you in public timelines
- If you and the blocked user are on the same server, the blocked user
  will not be able to view your posts on your profile while logged in.

If you block an entire server:

- You will not see posts from that server on the public timelines
- You won’t see other people’s boosts of that server in your home feed
- You won’t see notifications from that server
- You will lose any followers that you might have had on that server

### Top level documentation

- Provide clear instructions for how to hook the library up to a Phoenix
  application.

### Ontology generation tool

- Document the `ontology.gen` mix task.

### Other enhancements and bug fixes

- Limit the ranges and domains of properties and types according to
  the .jsonld ontology.
- Add builder methods (new, clear, set, get, etc) to restrict programmatic
  access to valid ranges and domains.
- `Fedi.Application.endpoint_url/0` should fetch the external endpoint
  URL from the implementing application, not the other way around.
  Maybe this can be done with a `__using__` macro, set up in the
  implementing application.

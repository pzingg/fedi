# Implementation checklist

From https://socialhub.activitypub.rocks/t/guide-for-new-activitypub-implementers/479/2#the-activitypub-spec-in-checkboxes-1


## Client to server interactions

### Actor object's outbox

1. [ ] Accepts Activity Objects (outbox:accepts-activities) MUST
2. [ ] Accepts non-Activity Objects, and converts to Create Activities per 7.1.1 (outbox:accepts-non-activity-objects) MUST
3. [ ] Removes the 'bto' and 'bcc' properties from Objects before storage and delivery (outbox:removes-bto-and-bcc) MUST
4. [ ] Ignores id on submitted objects, and generates a new id instead (outbox:ignores-id) MUST
5. [ ] Responds with status code 201 Created (outbox:responds-201-created) MUST
6. [ ] Response includes Location header whose value is id of new object, unless the Activity is transient (outbox:location-header)
7. [ ] Server does not trust client submitted content (outbox:not-trust-submitted) SHOULD
8. [ ] Validate the content they receive to avoid content spoofing attacks (outbox:validate-content) SHOULD
9. [ ] Take care not to overload other servers with delivery submissions (outbox:do-not-overload) SHOULD

10. [ ] Uploaded Media
    10.1. [ ] Accepts Uploaded Media in submissions (outbox:upload-media) MUST
    10.2. [ ] Accepts 'uploadedMedia' file parameter (outbox:upload-media:file-parameter) MUST
    10.3. [ ] Accepts 'uploadedMedia' object parameter (outbox:upload-media:object-parameter) MUST
    10.4. [ ] Responds with status code of 201 Created or 202 Accepted as described in 6. (outbox:upload-media:201-or-202-status) MUST
    10.5. [ ] Response contains a Location header pointing to the to-be-created object's id (outbox:upload-media:location-header) MUST
    10.6. [ ] Appends an 'id' property to the new object (outbox:upload-media:appends-id) MUST
    10.7. [ ] After receiving submission with uploaded media, the server should include the upload's new URL in the submitted object's 'url' property (outbox:upload-media:url) SHOULD

11. [ ] Update
    11.1. [ ] Server takes care to be sure that the Update is authorized to modify its object before modifying the server's stored copy (outbox:update:check-authorized) MUST
    11.2. [ ] Supports partial updates in client-to-server protocol (but not server-to-server) (outbox:update:partial) NON-NORMATIVE

12. [ ] Create
    12.1. [ ] Merges audience properties ('to', 'bto', 'cc', 'bcc', 'audience') with the Create's object's audience properties (outbox:create:merges-audience-properties) SHOULD
    12.2. [ ] Create's 'actor' property is copied to be the value of the object's 'attributedTo' property (outbox:create:actor-to-attributed-to) SHOULD

13. [ ] Follow
    13.1. [ ] Adds followed object to the actor's Following Collection (outbox:follow:adds-followed-object) SHOULD

14. [ ] Add
    14.1. [ ] Adds object to the target Collection, unless not allowed due to requirements in 7.5 (outbox:add:adds-object-to-target) SHOULD

15. [ ] Remove
    15.1. [ ] Remove object from the target Collection, unless not allowed due to requirements in 7.5 (outbox:remove:removes-from-target) SHOULD

16. [ ] Like
    16.1. [ ] Adds the object to the actor's Liked Collection (outbox:like:adds-object-to-liked) SHOULD

17. [ ] Block
    17.1. [ ] Prevent the blocked object from interacting with any object posted by the actor (outbox:block:prevent-interaction-with-actor) SHOULD

18. [ ] Undo
    18.1. [ ] Supports the Undo activity in the client-to-server protocol (outbox:undo) NON-NORMATIVE
    18.2. [ ] Ensures that the actor in the activity actor is the same in activity being undone (outbox:undo:ensures-activity-and-actor-are-same) MUST

### Actor object's inbox

1. [ ] Delivery
    1.1. [ ] Performs delivery on all Activities posted to the outbox (inbox:delivery:performs-delivery) MUST
    1.2. [ ] Utilizes 'to', 'bto', 'cc', and 'bcc' to determine delivery recipients. (inbox:delivery:addressing) MUST
    1.3. [ ] Provides an id all Activities sent to other servers, unless the activity is intentionally transient (inbox:delivery:adds-id) MUST
    1.4. [ ] Dereferences delivery targets with the submitting user's credentials (inbox:delivery:submit-with-credentials) MUST
    1.5. [ ] Delivers to all items in recipients that are Collections or OrderedCollections (inbox:delivery:deliver-to-collection) MUST
    1.6. [ ] Applies the above, recursively if the Collection contains Collections, and limits recursion depth >= 1 (inbox:delivery:deliver-to-collection:recursively) MUST
    1.7. [ ] Delivers activity with 'object' property if the Activity type is one of Create, Update, Delete, Follow, Add, Remove, Like, Block, Undo (inbox:delivery:delivers-with-object-for-certain-activities) MUST
    1.8. [ ] Delivers activity with 'target' property if the Activity type is one of Add, Remove (inbox:delivery:delivers-with-target-for-certain-activities) MUST
    1.9. [ ] Deduplicates final recipient list (inbox:delivery:deduplicates-final-recipient-list) MUST
    1.10 [ ] Does not deliver to recipients which are the same as the actor of the Activity being notified about (inbox:delivery:do-not-deliver-to-actor) MUST
    1.11 [ ] SHOULD NOT deliver Block Activities to their object (inbox:delivery:do-not-deliver-block) SHOULD NOT
    1.12 [ ] Delivers to sharedInbox endpoints to reduce the number of receiving actors delivered to by identifying all followers which share the same sharedInbox who would otherwise be individual recipients and instead deliver objects to said sharedInbox (inbox:delivery:sharedInbox) MAY
    1.13 [ ] (For servers which deliver to sharedInbox:) Deliver to actor inboxes and collections otherwise addressed which do not have a sharedInbox (inbox:delivery:sharedInbox:deliver-to-inbox-if-no-sharedInbox) MUST

2. [ ] Accept
    2.1. [ ] Deduplicates activities returned by the inbox by comparing activity ids (inbox:accept:deduplicate) MUST
    2.2. [ ] Forwards incoming activities to the values of 'to', 'bto', 'cc', 'bcc', and 'audience' if and only if criteria in 7.1.2 are met (inbox:accept:special-forward) MUST
    2.3. [ ] Recurse through 'to', 'bto', 'cc', 'bcc', and 'audience' object values to determine whether/where to forward according to criteria in 7.1.2 (inbox:accept:special-forward:recurses) SHOULD
    2.4. [ ] Limit recursion in this process (inbox:accept:special-forward:limits-recursion) SHOULD

3. [ ] Create
    3.1. [ ] Supports receiving a Create object in an actor's inbox (inbox:accept:create) NON-NORMATIVE

4. [ ] Delete
    4.1. [ ] Assuming object is owned by sending actor/server, removes object's representation (inbox:accept:delete) SHOULD
    4.2. [ ] replace object's representation with a Tombstone object (inbox:accept:delete:tombstone) MAY

5. [ ] Update
    5.1. [ ] Take care to be sure that the Update is authorized to modify its object (inbox:accept:update:is-authorized) MUST
    5.2. [ ] Completely replace its copy of the activity with the newly received value) (inbox:accept:update:completely-replace) SHOULD
    5.3. [ ] Don't trust content received from a server other than the content's origin without some form of verification (inbox:accept:dont-blindly-trust) SHOULD

6. [ ] Follow
    6.1. [ ] Add the actor to the object user's Followers Collection (inbox:accept:follow:add-actor-to-users-followers) SHOULD
    6.2. [ ] Generates either an Accept or Reject activity with Follow as object and deliver to actor of the Follow (inbox:accept:follow:generate-accept-or-reject) SHOULD
    6.3. [ ] If in reply to a Follow activity, adds actor to receiver's Following Collection (inbox:accept:accept:add-actor-to-users-following) SHOULD
    6.4. [ ] If in reply to a Follow activity, MUST NOT add actor to receiver's Following Collection (inbox:accept:reject:does-not-add-actor-to-users-following) MUST

7. [ ] Add
    7.1. [ ] Add the object to the Collection specified in the 'target' property, unless not allowed to per requirements in 7.8 (inbox:accept:add:to-collection) SHOULD

8. [ ] Remove
    8.1. [ ] Remove the object from the Collection specified in the 'target' property, unless not allowed per requirements in 7.9 (inbox:accept:remove:from-collection) SHOULD

9. [ ] Like
    9.1. [ ] Perform appropriate indication of the like being performed (See 7.10 for examples) (inbox:accept:like:indicate-like-performed) SHOULD
    9.2. [ ] Increments object's count of shares by adding the received activity to the 'shares' collection if this collection is present (inbox:accept:announce:add-to-shares-collection) SHOULD

10. [ ] Undo
    10.1. [ ] Performs Undo of object in federated context (inbox:accept:undo) NON-NORMATIVE
    10.2. [ ] Validate the content they receive to avoid content spoofing attacks (inbox:accept:validate-content) SHOULD

## Common server support

### Inbox retrieval

1. [ ] Server responds to GET request at inbox URL (server:inbox:responds-to-get) NON-NORMATIVE
2. [ ] inbox is an OrderedCollection (server:inbox:is-orderedcollection) MUST
3. [ ] Server filters inbox content according to the requester's permission (server:inbox:filtered-per-permissions) SHOULD

### Object retrieval

1. [ ] Allow dereferencing Object ids by responding to HTTP GET requests with a representation of the Object (server:object-retrieval:get-id) MAY
2. [ ] Respond with the ActivityStreams object representation in response to requests that primarily Accept the media type application/ld+json; profile="https://www.w3.org/ns/activitystreams" (server:object-retrieval:respond-with-as2-re-ld-json) MUST
3. [ ] Respond with the ActivityStreams object representation in response to requests that primarily Accept the media type application/activity+json (server:object-retrieval:respond-with-as2-re-activity-json) SHOULD
4. [ ] Responds with response body that is an ActivityStreams Object of type Tombstone (if the server is choosing to disclose that the object has been removed) (server:object-retrieval:deleted-object:tombstone) MAY
5. [ ] Respond with 410 Gone status code if Tombstone is in response body, otherwise responds with 404 Not Found (server:object-retrieval:deleted-object:410-status) SHOULD
6. [ ] Respond with 404 status code for Object URIs that have never existed (server:object-retrieval:deleted-object:404-status) SHOULD
7. [ ] Respond with a 403 Forbidden status code to all requests that access Objects considered Private (or 404 if the server does not want to disclose the existence of the object, or another HTTP status code if specified by the authorization method)) (server:object-retrieval:private-403-or-404) SHOULD

### Security considerations

1. [ ] Server verifies that the new content is really posted by the actor indicated in Objects received in inbox and outbox (server:security-considerations:actually-posted-by-actor) NON-NORMATIVE
2. [ ] By default, implementation does not make HTTP requests to localhost when delivering Activities (server:security-considerations:do-not-post-to-localhost) NON-NORMATIVE
3. [ ] Implementation applies a whitelist of allowed URI protocols before issuing requests, e.g. for inbox delivery (server:security-considerations:uri-scheme-whitelist) NON-NORMATIVE
4. [ ] Server filters incoming content both by local untrusted users and any remote users through some sort of spam filter (server:security-considerations:filter-incoming-content) NON-NORMATIVE
5. [ ] Implementation takes care to sanitize fields containing markup to prevent cross site scripting attacks) (server:security-considerations:sanitize-fields) NON-NORMATIVE

## Client applications

### Submission

1. [ ] Client discovers the URL of a user's outbox from their profile (client:submission:discovers-url-from-profile) MUST
2. [ ] Client submits activity by sending an HTTP post request to the outbox URL with the Content-Type of application/ld+json; profile="https://www.w3.org/ns/activitystreams" (client:submission:submit-post-with-content-type) MUST
3. [ ] Client submission request body is either a single Activity or a single non-Activity Object (client:submission:submit-objects) MUST
4. [ ] Clients provide the 'object' property when submitting the following activity types to an outbox: Create, Update, Delete, Follow, Add, Remove, Like, Block, Undo (client:submission:submit-objects:provide-object) MUST
5. [ ] Clients provide the 'target' property when submitting the following activity types to an outbox: Add, Remove. (client:submission:submit-objects:provide-target) MUST
6. [ ] Client submission request is authenticated with the credentials of the user to whom the outbox belongs (client:submission:authenticated) MUST
7. [ ] Client supports uploading media by sending a multipart/form-data request body (client:submission:uploading-media) MUST
8. [ ] Before submitting a new activity or object, Client infers appropriate target audience by recursively looking at certain properties (e.g. 'inReplyTo', See Section 7), and adds these targets to the new submission's audience (client:submission:recursively-add-targets) SHOULD
9. [ ] Client limits depth of this recursion (client:submission:recursively-add-targets:limits-depth) SHOULD

### Retrieval

1. [ ] When retrieving objects, Client specifies an Accept header with the application/ld+json; profile="https://www.w3.org/ns/activitystreams" media type (3.2 1) (client:retrieval:accept-header) MUST

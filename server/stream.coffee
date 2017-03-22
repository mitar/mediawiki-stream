util = require 'util'
EventSource = require 'eventsource'

STREAM_TTL = 60 # seconds

# Auto-expire messages after STREAM_TTL seconds.
Stream._ensureIndex
  _ts: 1
,
  expireAfterSeconds: STREAM_TTL

Stream._ensureIndex
  wiki: 1

Stream._ensureIndex
  timestamp: 1

Stream._ensureIndex
  id: 1

Stream._ensureIndex
  wiki: 1
  timestamp: 1
  id: 1
  'log_params.log': 1
,
  unique: true

mediawikiAPI = (url, params) ->
  response = HTTP.get url,
    params: params
    headers:
     'User-Agent': "WikiMedia Meteor DDP stream (#{ Meteor.absoluteUrl() }, mitar.wikimediastream@tnode.com)"
    npmRequestOptions:
      forever: true # Enable keep-alive.

  data = response.data

  if data.error
    if _.isObject data.error
      error = util.inspect data.error, showHidden: false, depth: null
    else
      error = data.error
    throw new Error "API Error: #{ url }, #{ util.inspect params, showHidden: false, depth: null }, #{ error }"

  console.warn data.warnings if data.warnings

  data

handleException = (error) ->
  console.error "Exception in stream change processing: #{ error.stack or error }"

Meteor.startup ->
  # Connect to WikiMedia stream.
  # TODO: Are there other streams for other MediaWiki installations? Should this be configurable?
  eventSource = new EventSource('https://stream.wikimedia.org/v2/stream/recentchange');

  eventSource.on 'open', (event) ->
    console.log "Stream connected"

  eventSource.on 'error', (event) ->
    # TODO: Do we have to reconnect?
    console.log "Stream error", event

  eventSource.on 'message', Meteor.bindEnvironment (event) ->
    # Store receive (and expiry) timestamp.
    timestamp = new Date()

    data = JSON.parse event.data

    try

      if data.type is 'new'
        responseData = mediawikiAPI "#{ data.server_url }#{ data.server_script_path }/api.php",
          format: 'json'
          action: 'query'
          prop: 'revisions'
          revids: data.revision.new
          rvprop: 'content'
          continue: ''

        # It should be only one result, so nothing to continue ever.
        assert not responseData.continue, "Continue for revids #{ data.revision.new }"

        data.query = responseData.query

      else if data.type is 'edit'
        responseData = mediawikiAPI "#{ data.server_url }#{ data.server_script_path }/api.php",
          format: 'json'
          action: 'compare'
          fromrev: data.revision.old
          torev: data.revision.new

        data.compare = responseData.compare

    catch error
      console.error "Exception in fetching API data for #{ util.inspect data, showHidden: false, depth: null }: #{ error.stack or error }"

    # Set receive (and expiry) timestamp. We do it last so that it is the last in the object.
    # It just looks a bit better when printing the objects out.
    data._ts = timestamp

    Stream.upsert
      $and: [
        wiki: data.wiki
      ,
        timestamp: data.timestamp
      ,
        id: data.id
      ,
        'log_params.log': data.log_params?.log
      ]
    ,
      $setOnInsert: data
  ,
    handleException

Meteor.publish 'mediawiki-stream', (selector, projectionFields, includeCached) ->
  check selector, Object
  check projectionFields, Match.Optional Match.OneOf null, Object
  check includeCached, Match.Optional Match.OneOf null, Boolean

  projectionFields ?= {}
  includeCached ?= false

  remove = (id) =>
    # Because we are potentially not including cached documents, or we are removing an already
    # removed document, we should check if we are publishing a document before removing it.
    stringId = @_idFilter.idStringify id
    @removed 'mediawiki_stream', id if stringId of @_documents.mediawiki_stream

  initializing = true

  handle = Stream.find(selector, fields: projectionFields).observeChanges
    added: (id, fields) =>
      if includeCached or not initializing
        @added 'mediawiki_stream', id, fields

        # Make sure document is removed after STREAM_TTL seconds. MongoDB does not always expire
        # documents on time, or observeChanges does not always detect expired documents quickly.
        Meteor.setTimeout =>
          remove id
        ,
          STREAM_TTL * 1000 # ms
    removed: (id) =>
      remove id

  initializing = false

  @ready()

  @onStop =>
    handle.stop()

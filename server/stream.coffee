util = require 'util'

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
    forever: true # Enable keep-alive.
    params: params
    headers:
     'User-Agent': "WikiMedia Meteor DDP stream (#{ Meteor.absoluteUrl() }, mitar.wikimediastream@tnode.com)"

  data = response.data

  if data.error
    if _.isObject data.error
      error = util.inspect data.error, false, null
    else
      error = data.error
    throw new Error "API Error: #{ url }, #{ util.inspect params, false, null }, #{ error }"

  console.warn data.warnings if data.warnings

  data

handleException = (error) ->
  console.error "Exception in stream change processing: #{ error.stack or error }"

Meteor.startup ->
  # Connect to WikiMedia stream.
  # TODO: Are there other streams for other MediaWiki installations? Should this be configurable?
  socket = io.connect 'https://stream.wikimedia.org/rc'

  socket.on 'connect', ->
    console.log "Stream connected"

    # Subscribe to all wikis.
    socket.emit 'subscribe', '*'

  socket.on 'disconnect', ->
    # TODO: Do we have to reconnect?
    console.log "Stream disconnected"

  socket.on 'change', Meteor.bindEnvironment (data) ->
    # Store receive (and expiry) timestamp.
    timestamp = new Date()

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
      console.error "Exception in fetching API data for #{ util.inspect data, false, null }: #{ error.stack or error }"

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

  socket.on 'error', (error) ->
    console.log "Stream error", error

  socket.on 'reconnect', (args...) ->
    console.log "Stream reconnection", args...

  socket.on 'reconnecting', (args...) ->
    console.log "Stream reconnecting", args...

  socket.on 'reconnect_error', (error) ->
    console.log "Stream reconnect error", error

  socket.on 'reconnect_failed', ->
    console.log "Stream reconnection failed"

Meteor.publish 'mediawiki-stream', (selector, projectionFields, includeCached) ->
  check selector, Object
  check projectionFields, Match.Optional Match.OneOf null, Object
  check includeCached, Match.Optional Match.OneOf null, Boolean

  projectionFields ?= {}
  includeCached ?= false

  initializing = true

  handle = Stream.find(selector, fields: projectionFields).observeChanges
    added: (id, fields) =>
      if includeCached or not initializing
        # We add and immediately remove the document.
        @added 'mediawiki_stream', id, fields
        @removed 'mediawiki_stream', id

  initializing = false

  @ready()

  @onStop =>
    handle.stop()

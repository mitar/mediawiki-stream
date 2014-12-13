STREAM_TTL = 60 # seconds

# Auto-expire messages after STREAM_TTL seconds.
Stream._ensureIndex
  _ts: 1
,
  expireAfterSeconds: STREAM_TTL

Meteor.startup ->
  # Connect to WikiMedia stream.
  # TODO: Are there other streams for other MediaWiki installations? Should this be configurable?
  socket = io.connect 'http://stream.wikimedia.org/rc'

  socket.on 'connect', ->
    console.log "Stream connected"

    # Subscribe to all wikis.
    socket.emit 'subscribe', '*'

  socket.on 'disconnect', ->
    # TODO: Do we have to reconnect?
    console.log "Stream disconnected"

  socket.on 'change', Meteor.bindEnvironment (data) ->
    # TODO: Do we want to fetch also change data itself?

    # Set receive (and expiry) timestamp to the current time.
    data._ts = new Date()

    if data.type is 'new'
      # TODO: How to get data for new pages?

    else if data.type is 'edit'
      response = HTTP.get "#{ data.server_url }#{ data.server_script_path }/api.php",
        forever: true # Enable keep-alive.
        params:
          format: 'json'
          action: 'compare'
          fromrev: data.revision.old
          torev: data.revision.new
        headers:
         'User-Agent': 'WikiMedia Meteor DDP stream (http://wikimedia.meteor.com/, mitar.wikimediastream@tnode.com)'

      data.compare = response.data.compare

    Stream.insert data

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

Meteor.publish 'mediawiki-stream', (selector, fields, includeCached) ->
  check selector, Object
  check fields, Match.Optional Match.OneOf null, Object
  check includeCached, Match.Optional Match.OneOf null, Boolean

  fields ?= {}
  includeCached ?= false

  initializing = true

  handle = Stream.find(selector, fields: fields).observeChanges
    added: (id, fields) =>
      @added 'mediawiki_stream', id, fields if includeCached or not initializing

  initializing = false

  @ready()

  @onStop =>
    handle.stop()

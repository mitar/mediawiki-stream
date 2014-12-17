@LocalStream = new Meteor.Collection null

# We use setDefault so that values are kept between hot reloads.
Session.setDefault 'selectorString', "{wiki: 'enwiki', bot: false, minor: false}"
Session.setDefault 'selectorObject', {wiki: 'enwiki', bot: false, minor: false}
Session.setDefault 'fieldsString', '{}'
Session.setDefault 'fieldsObject', {}

# We always initialize errors to null because they are not valid after a hot reload.
# We do not have ti initialize subscriptionError because it is initialized in autorun.
Session.set 'selectorError', null
Session.set 'fieldsError', null

# We copy documents from the stream to the local collection.
Stream.find({}).observeChanges
  'added': (id, fields) ->
    LocalStream.insert _.extend {_id: id}, fields

# Regularly expire old documents from the local collection.
Meteor.setInterval ->
  LocalStream.find({},
    sort: [
      ['_ts', 'desc']
    ]
    skip: 50
  ).forEach (document) ->
    LocalStream.remove document._id
,
  5000 # ms

Tracker.autorun ->
  Session.set 'subscriptionError', null
  Meteor.subscribe 'mediawiki-stream', Session.get('selectorObject'), Session.get('fieldsObject'),
    onError: (error) ->
      Session.set 'subscriptionError', "#{ error }"

Template.body.helpers
  endpoint: ->
    Meteor.absoluteUrl()

Template.apiExplorer.helpers
  disconnected: ->
    not Meteor.status()?.connected

  subscriptionError: ->
    Session.get 'subscriptionError'

  selectorString: ->
    Session.get 'selectorString'

  selectorObject: ->
    Session.get 'selectorObject'

  selectorError: ->
    Session.get 'selectorError'

  fieldsString: ->
    Session.get 'fieldsString'

  fieldsObject: ->
    Session.get 'fieldsObject'

  fieldsError: ->
    Session.get 'fieldsError'

parseObject = (string) ->
  object = eval "(function () { return #{ string } })()"

  throw new Error "Not an object" unless _.isObject object

  object

Template.apiExplorer.events
  'click .reconnect': (event, template) ->
    event.preventDefault()

    Meteor.reconnect()

    return

  'submit .api-explorer-form': (event, template) ->
    event.preventDefault()

    try
      selectorString = template.$('.selector').val()
      selectorObject = parseObject selectorString
      Session.set 'selectorError', null
    catch error
      Session.set 'selectorError', "#{ error }"

    try
      fieldsString = template.$('.fields').val()
      fieldsObject = parseObject fieldsString
      Session.set 'fieldsError', null
    catch error
      Session.set 'fieldsError', "#{ error }"

    return if Session.get('selectorError') or Session.get('fieldsError')

    Session.set 'selectorString', selectorString
    Session.set 'selectorObject', selectorObject
    Session.set 'fieldsString', fieldsString
    Session.set 'fieldsObject', fieldsObject

    return

Template.apiResults.helpers
  results: ->
    LocalStream.find {},
      sort: [
        ['_ts', 'desc']
      ]
      limit: 50

Template.renderjson.rendered = ->
  @autorun =>
    @$('.renderjson-wrapper').empty().append renderjson.set_icons('+', '-').set_show_to_level(2) EJSON.toJSONValue Template.currentData()

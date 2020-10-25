# Repeat every 1 day.
REPEAT_INTERVAL = 24 * 60 * 60 * 1024 # ms

# Because we use TTL index and use it a lot, index grows rapidly and over the time can become huge
# in comparison with real data. This is why we daily repair the database to get it to manageable levels.
Meteor.setInterval ->
  DirectCollection.command
    repairDatabase: 1
, REPEAT_INTERVAL

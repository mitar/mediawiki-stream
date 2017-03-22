JobsWorker.initialize()

# Repeat every 1 day.
REPEAT_INTERVAL = 24 * 60 * 60 * 1024 # ms

# Because we use TTL index and use it a lot, index grows rapidly and over the time can become huge
# in comparison with real data. This is why we daily repair the database to get it to manageable levels.
class RepairDatabaseJob extends Job
  @register()

  enqueueOptions: (options) ->
    options = super

    _.defaults options,
      priority: 'low'
      retry:
        wait: REPEAT_INTERVAL
      repeat:
        wait: REPEAT_INTERVAL
      delay: REPEAT_INTERVAL / 2
      save:
        cancelRepeats: true

  run: ->
    DirectCollection.command
      repairDatabase: 1

Meteor.startup ->
  JobsWorker.start()

  new RepairDatabaseJob().enqueue() if JobsWorker.options.workerInstances

# WikiMedia recent changes DDP API

WikiMedia wikis (of which <a href="https://www.wikipedia.org/">Wikipedia</a> is the most known) provide a
[stream of recent changes](https://wikitech.wikimedia.org/wiki/EventStreams). If you want to subscribe to them
in a [Meteor](https://www.meteor.com/) application (or [any other application supporting DDP protocol](http://www.meteorpedia.com/read/DDP_Clients)),
you can instead connect to the [`https://wikimedia.meteorapp.com/`](https://wikimedia.meteorapp.com/) DDP endpoint
and subscribe to the publish endpoint which publishes those recent changes. The advantage is that you can filter to only
those changes you care about using MongoDB selectors, and project only fields you want. Moreover, changes of adding
or editing wiki content are augmented with the information about the change itself, e.g., a diff of the change.

See [`https://wikimedia.meteorapp.com/`](https://wikimedia.meteorapp.com/) for more information and documentation.
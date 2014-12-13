Package.describe({
  summary: "Render JSON into collapsible HTML",
  version: '0.0.1'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@1.0');

  api.export('renderjson', 'client');

  api.addFiles('renderjson/renderjson.js', 'client');
});

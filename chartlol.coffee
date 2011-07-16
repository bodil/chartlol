express = require 'express'
eco = require 'eco'
stylus = require 'stylus'

app = express.createServer()
app.configure ->
  app.register ".eco", eco
  app.set "views", "#{__dirname}/views"
  app.set "view engine", "eco"
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session
    secret: "foo"
  app.use stylus.middleware
    src: "#{__dirname}/public"
  app.use app.router
  app.use express.static "#{__dirname}/public"

app.configure "development", ->
  app.use express.errorHandler
    dumpExceptions: true
    showStack: true

app.configure "production", ->
  app.use express.errorHandler()

app.get '/', (req, res) ->
  res.render "index",
    title: "ohai"

app.listen parseInt(process.env.PORT, 10) || 1337
console.log "Listening on port #{app.address().port} in #{app.settings.env} mode"

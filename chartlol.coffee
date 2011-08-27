express = require 'express'
stylus = require 'stylus'
hash = require 'password-hash'
mongoose = require 'mongoose'
MongoStore = require 'connect-mongo'
model = require './model'

mongo_uri = process.env.MONGOLAB_URI || "mongodb://localhost/chartlol"
console.log "Connecting to #{mongo_uri}"
mongoose.connect mongo_uri, (err) ->
  console.log if err? then "Mongoose: #{err.message}" else "Mongoose connected."


app = express.createServer()
app.configure ->
  app.set "views", "#{__dirname}/views"
  app.set "view engine", "jade"
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session
    secret: "foo"
    store: new MongoStore
      url: mongo_uri
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

extend = (one, two) ->
  one[key] = value for own key, value of two
  one

local = (req, context) ->
  if req.session.msg
    context.msg = req.session.msg
    req.session.msg = null
  else
    context.msg = null
  extend context,
    session: req.session

validate_credentials = (req, res) ->
  u = req.param "username"
  p = req.param "password"
  if not /^[a-zA-Z0-9_]{3,24}$/.test u
    req.session.msg = "Username must be at least 3 characters long, and can only contain letters, numbers and underscores."
    res.redirect '/login'
    [null, null]
  else if not /^.{6,24}$/.test p
    req.session.msg = "Password must be at least 6 characters long."
    res.redirect '/login'
    [null, null]
  else
    [u, p]

app.get '/', (req, res) ->
  if req.session.user
    model.Chart.find { owner: req.session.user }, (err, charts) ->
      if not err
        res.render "index", local req,
          title: null
          charts: charts
      else
        throw err
  else
    res.render "landing", local req,
      title: null

app.get '/login', (req, res) ->
  res.render "login", local req,
    title: "Login"

app.post '/login', (req, res) ->
  [u, p] = validate_credentials req, res
  if u
    model.User.findOne user: u, (err, user) =>
      if not err
        if user
          if hash.verify p, user.password
            req.session.user = user.user
            res.redirect '/'
          else
            req.session.msg = "Incorrect password for username. Try a different username?"
            req.session.user = null
            res.redirect '/login'
        else
          req.session.tmp_password_hash = hash.generate p
          req.session.tmp_username = u
          res.redirect '/register'
      else
        throw err

app.get '/register', (req, res) ->
  res.render "register", local req,
    title: "New User"
    username: req.session.tmp_username

app.post '/register', (req, res) ->
  [u, p] = validate_credentials req, res
  if u
    model.User.findOne user: (req.param "username"), (err, user) =>
      if not err
        if user
          req.session.msg = "That username is already taken. Try again with another username."
          res.redirect '/login'
        else
          if hash.verify (req.param "password"), req.session.tmp_password_hash
            user = new model.User
              user: req.session.tmp_username
              password: req.session.tmp_password_hash
            req.session.tmp_username = req.session.tmp_password_hash = null
            user.save (err) ->
              if err
                session.msg = "That username is already taken. Try again with another username."
                redirect '/login'
              else
                req.session.user = user.user
                res.redirect '/'
          else
            req.session.msg = "Your passwords don't match. I'm afraid you're going to have to start over."
            req.session.user = null
            res.redirect '/login'
      else
        throw err

app.listen parseInt(process.env.PORT, 10) || 1337
console.log "Listening on port #{app.address().port} in #{app.settings.env} mode"


# Dependencies
path = require 'path'
express = require 'express'
app = express()
http = require 'http'
server = http.createServer app
request = require 'request'
redis = require 'redis'
mongoose = require 'mongoose'
fs = require 'fs'
marked = require 'marked'
require './helpers'

global.config =
  site:
    url: process.env.SITE_URL || 'http://localhost:3000'
  redis:
    port: process.env.REDIS_PORT || 6379
    host: process.env.REDIS_HOST || 'localhost'
    pre: process.env.REDIS_PRE || 'throwandtell'
    auth: process.env.REDIS_AUTH || null
    noReadyCheck: process.env.REDIS_NOREADYCHECK || false
  mongo:
    host: process.env.MONGO_HOST || 'localhost'
    db: process.env.MONGO_DB || 'ThrowAndTell'
  github:
    clientId: process.env.GITHUB_CLIENTID || false
    clientSecret: process.env.GITHUB_CLIENTSECRET || false

if not config.github.clientId or not config.github.clientSecret
  console.log 'WARNING: There is no GitHub Authentication Info Set.'

# DB Connections
global.redisClient = redis.createClient config.redis.port, config.redis.host, {no_ready_check: config.redis.noReadyCheck}

if process.env.MONGOLAB_URI
  global.db = mongoose.createConnection(process.env.MONGOLAB_URI);
else if process.env.MONGOHQ_URL
  global.db = mongoose.createConnection(process.env.MONGOHQ_URL);
else
  global.db = mongoose.createConnection(config.mongo.host, config.mongo.db);

db.on 'error', console.error.bind(console, 'connection error:')
db.once 'open', () ->
  console.log 'Connected to DB'

schemaFiles = fs.readdirSync './db/schemas'
for filename in schemaFiles
  splitFilename = filename.split '.'
  schemaName = splitFilename[0].charAt(0).toUpperCase() + splitFilename[0].slice(1);
  global[schemaName] = db.model schemaName, new mongoose.Schema(require('./db/schemas/' + filename))

# Marked (Markdown Render Config)
marked.setOptions
  gfm: true
  pedantic: false
  sanitize: true

  # callback for code highlighter
  highlight: (code, lang) ->
    return javascriptHighlighter(code)  if lang is "js"
    code

# Config
app.set 'view engine', 'html'
app.engine 'html', require('hbs').__express
app.use express.logger('dev')
app.use express.bodyParser()
app.use express.cookieParser('Newton Faulkner, Keep this secure')
app.use express.cookieSession()

# Auth req.user = profile
app.use (req, res, next) ->
  if req.session.user
    getUser req.session.user, (err, user) ->
      next err if err
      req.user = res.locals.user = user
      next()
  else
    next()

# Flash Messages
app.use (req, res, next) ->
  if req.session.flashes
    res.locals.flashMessages = req.session.flashes
  else
    req.session.flashes = []
  next()

app.use express.static __dirname + '/public'

# Routes

# Auth Routes

app.get '/auth', (req, res, next) ->
  res.redirect 'https://github.com/login/oauth/authorize?client_id=' + config.github.clientId + '&scope=repo'

app.get '/auth/callback', (req, res, next) ->

  # Check Credentials

  request.post 
    uri: 'https://github.com/login/oauth/access_token',
    json:
      client_id: config.github.clientId
      client_secret: config.github.clientSecret
      code: req.query.code
      state: null
    headers:
      Accept: 'application/json'
  , (err, GHres, body) ->
    next err if err
    next 'No access_token' unless body.access_token

    accessToken = body.access_token

    request.get 
      uri: 'https://api.github.com/user?access_token=' + accessToken
      json: true
    , (err, GHUserRes, user) ->
      next err if err

      user.date_synced = new Date()
      save 'user', user.id, 'github_user', user, (err) ->
        next err if err
        save 'user', user.id, 'github_token', accessToken, (err) ->
          next err if err

          req.session.user = user.id
          res.redirect '/'

app.get '/logout', (req, res, next) ->
  next() unless req.session
  req.session = null
  res.redirect '/'

# Dashboard Routes

app.get '/', (req, res, next) ->
  authenticated = false
  #res.redirect '/auth' unless authenticated
  if typeof req.session.user == 'undefined'
    res.render 'index'
  else
    Key.find
      createdBy: req.user.id
    , (err, keys) ->
      next err if err
      res.locals.keys = keys
      res.render 'home'

app.post '/new', (req, res, next) ->
  keyData =
    createdBy: req.user.id
    repository: req.body.repository
  generateKey keyData, (err, keyObject) ->
    next err if err
    res.redirect '/#key-' + keyObject._id


app.get '/:key/delete', (req, res, next) ->
  res.send 404 unless req.user
  Key.findOne
    _id: req.params.key
    createdBy: req.user.id
  , (err, doc) ->
    next err if err
    if doc
      doc.remove (err) ->
        next err if err
        # Flashify Key {{_id}} Successfully Deleted
        res.redirect '/'
    else
      res.send 404

# Docs Routes

app.get '/docs/api', (req, res, next) ->
  res.redirect '/docs/api/v1'

app.get '/docs/*', (req, res, next) ->
  docpath = path.resolve __dirname, './docs', req.params[0] + '.md'
  fs.exists docpath, (exists) ->
    if exists
      fs.readFile docpath, (err, data) ->
        res.render 'layout',
          layout: false
          body: marked data.toString()
    else
      next()

# API Routes

app.post '/api/v1/report', (req, res, next) ->

  res.send {error:'No App Key Provided'} unless req.query.access_key
  res.send {error:'No Report Body Provided'} unless req.body.body || req.body.trace

  if req.body.trace
    splitTrace = req.body.trace.split('\n')
    req.body.body += "\n\n" if req.body.body
    req.body.body = '' unless req.body.body
    for line in splitTrace
      req.body.body = req.body.body + '    ' + line + '\n'
  Key.findOne
    _id: req.query.access_key.substring(0,24)
    secret: req.query.access_key.substring(24)
  , (err, key) ->
    next err if err
    return res.send {error: 'Unauthenticated'} unless key

    getToken key.createdBy, (err, accessToken) ->
      request.post
        uri: 'https://api.github.com/repos/' + key.repository + '/issues?access_token=' + accessToken
        json:
          title: req.body.title || 'ThrowAndTell Report'
          body: req.body.body + '\n\nReported By [ThrowAndTell](' + config.site.url + ')'
      , (err, GHIssueRes, issue) ->
        console.error err if err
        res.send {error:false, result:true}


# Start Up (Possibly After Redis Auth)

if config.redis.auth
  redisClient.on 'ready', () ->
    redisClient.auth config.redis.auth ,(err) ->
      if err
        console.log err
      else
        server.listen process.env.PORT or 3000
else
  server.listen process.env.PORT or 3000


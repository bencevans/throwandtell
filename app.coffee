
# Dependencies
express = require 'express'
app = express()
http = require 'http'
server = http.createServer app
request = require 'request'
redis = require 'redis'
mongoose = require 'mongoose'
fs = require 'fs'
require './helpers'

global.config =
  redis:
    pre: 'throwandtell'
  mongo:
    host: 'localhost'
    db: 'ThrowAndTell'
  github:
    clientId: '8aad25eb6fae91c19f59'
    clientSecret: '78a9cd3c406312cdfc2f50c365c5498be91f76bb'

# DB Connections
global.redisClient = redis.createClient()

global.db = mongoose.createConnection(config.mongo.host, config.mongo.db);

db.on 'error', console.error.bind(console, 'connection error:')
db.once 'open', () ->
  console.log 'Connected to DB'

schemaFiles = fs.readdirSync './db/schemas'
for filename in schemaFiles
  splitFilename = filename.split '.'
  schemaName = splitFilename[0].charAt(0).toUpperCase() + splitFilename[0].slice(1);
  global[schemaName] = db.model schemaName, new mongoose.Schema(require('./db/schemas/' + filename))


# Config
app.set 'view engine', 'html'
app.engine 'html', require('hbs').__express
app.use express.logger('dev')
app.use express.bodyParser()
app.use express.cookieParser('Newton Faulkner, Keep this secure')
app.use express.cookieSession()
app.use (req, res, next) ->
  if req.session.user
    getUser req.session.user, (err, user) ->
      next err if err
      req.user = res.locals.user = user
      next()
  else
    next()

# Routes
app.get '/', (req, res, next) ->
  authenticated = false
  #res.redirect '/auth' unless authenticated
  if typeof req.session.user == 'undefined'
    res.sendfile 'public/index.html'
  else
    res.render 'home'

app.get '/style.css', (req, res) ->
  res.sendfile './public/style.css'

app.get '/auth', (req, res, next) ->
  res.redirect 'https://github.com/login/oauth/authorize?client_id=8aad25eb6fae91c19f59&scope=repo'

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


app.post '/api/v1/report', (req, res, next) ->

  res.send {error:'No App Key Provided'} unless req.query.access_key
  res.send {error:'No Report Body Provided'} unless req.body.body || req.body.trace

  if req.body.trace
    splitTrace = req.body.trace.split('\n')
    req.body.body += "\n\n" if req.body.body
    req.body.body = '' unless req.body.body
    for line in splitTrace
      req.body.body = req.body.body + '    ' + line + '\n'


  getToken 638535, (err, accessToken) ->
    request.post 
      uri: 'https://api.github.com/repos/bencevans/test/issues?access_token=' + accessToken
      json:
        title: req.body.title || 'ThrowAndTell Report'
        body: req.body.body + '\n\nReported By [ThrowAndTell](http://localhost:3000)'
    , (err, GHIssueRes, issue) ->
      console.error err if err


app.get '/logout', (req, res, next) ->
  next() unless req.session
  req.session = null
  res.redirect '/'


  ###
  github.issues.create
    user: 'bencevans'
    repo: 'test'
    title: 'Test Title'
    body: 'Big Stacktrace, remember to indent for markdown!'
  ###


# Start Up
server.listen process.env.PORT or 3000
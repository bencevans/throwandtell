randomstring = require 'randomstring'

global.argsToArray = (oldArgs) ->
  newArgs = []
  for arg in oldArgs
    newArgs.push arg
  return newArgs

global.save = () ->
  args = argsToArray arguments
  if args.length < 3
    throw new Error('Not Enouph Arguments')
  cb = args.pop()
  data = JSON.stringify args.pop()
  key = config.redis.pre ? config.redis.pre + ':' : ''
  key = key + args.join ':'
  redisClient.set key, data, cb

global.get = () ->
  args = argsToArray arguments
  if args.length < 2
    throw new Error('Not Enouph Arguments')
  cb = args.pop()
  key = config.redis.pre ? config.redis.pre + ':' : ''
  key = key + args.join ':'
  redisClient.get key, (err, data) ->
    cb err if err
    try
      data = JSON.parse data
    catch e
      cb e, data
    cb null, data

global.getUser = (GHId, cb) ->
  get 'user', GHId, 'github_user', cb

global.setUser = (GHId, data, cb) ->
  set 'user', GHId, 'github_user', data, cb

global.getToken = (GHId, cb) ->
  get 'user', GHId, 'github_token', cb

global.setToken = (GHId, data, cb) ->
  set 'user', GHId, 'github_token', data, cb


global.generateKey = (data, cb) ->
  data.secret = randomstring.generate 11
  new Key(data).save(cb)


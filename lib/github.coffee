module.exports = github

github.getToken = (code, cb) ->
  cb 'No Code Provided' unless code

  request.post 
    uri: 'https://github.com/login/oauth/access_token',
    json:
      client_id: '8aad25eb6fae91c19f59'
      client_secret: '78a9cd3c406312cdfc2f50c365c5498be91f76bb'
      code: req.query.code
      state: null
    headers:
      Accept: 'application/json'
  , (err, GHres, body) ->
    next err if err
    next 'No access_token' unless body.access_token

github.createClient = (config) ->
  return new GitHub config

GitHub = (config) ->
  throw new Error 'No Token Provided' unless config.token

GitHub
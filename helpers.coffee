
global.argsToArray = (oldArgs) ->
  newArgs = []
  for arg in oldArgs
    newArgs.push arg
  return newArgs
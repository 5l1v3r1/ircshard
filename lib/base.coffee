{Emitter} = require 'distobj'

###
events:
 - 'error': a fatal error has occured and the Manager cannot continue
 - 'disconnect': an error has occered for a specific user
 - 'message': a message has been received for a specific user
 - 'registered': a user has been registered with the IRC server
 - 'nick': the user changed their nick, args: username, new, old
###
class Manager extends Emitter
  constructor: (@server) -> super()

  register: (username, allMsg, password) -> @emit 'error', new Error 'NYI'

  join: (username, channel) -> @emit 'error', new Error 'NYI'

  say: (username, destination, message) -> @emit 'error', new Error 'NYI'

  disconnect: (username) -> @emit 'error', new Error 'NYI'

module.exports = Manager


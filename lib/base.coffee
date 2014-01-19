{Emitter} = require 'distobj'

###
events:
 - 'error': a fatal error has occured and the Manager cannot continue
 - 'disconnect': an error has occered for a specific user
 - 'message': a message has been received for a specific user
 - 'registered': a user has been registered with the IRC server
 - 'nick': the user changed their nick, args: username, new, old
 - 'nicklist': a user got a full nick list for a channel
 - 'enter': a user detected a nick entering a channel
 - 'exit': a user detected a nick leaving a channel
all of these events besides the `error` event will also fire an event
for the specific user, of the form event#user. For example, 'nick', 'alex'
would also fire 'nick#alex'
###
class Manager extends Emitter
  constructor: (@server) -> super()
  register: (username, allMsg, password) -> @emit 'error', new Error 'NYI'
  join: (username, channel) -> @emit 'error', new Error 'NYI'
  part: (username, channel) -> @emit 'error', new Error 'NYI'
  say: (username, destination, message) -> @emit 'error', new Error 'NYI'
  disconnect: (username) -> @emit 'error', new Error 'NYI'
  _emitUser: (event, username, args...) ->
    @emit event, username, args...
    @emit event + '#' + username, args...

module.exports = Manager


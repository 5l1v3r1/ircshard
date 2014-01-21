{Emitter} = require 'distobj'

###
events:
 - 'error': a fatal error has occured and the Manager cannot continue
 - 'registered': a user has been registered with the IRC server
 - 'disconnect': an error has occured for a specific user
 - 'message': a message has been received for a specific user
 - 'nick': a user changed their nick, args: username, new, old
 - 'nicklist': a user got a full nick list for a channel
 - 'enter': a user detected a nick entering a channel
 - 'exit': a user detected a nick leaving a channel. includes 'kick'
 - 'kill': a user saw a user get MURDERED
all of these events besides the `error` event will also fire an event
for the specific user, of the form event#user. For example, 'nick', 'alex'
would also fire 'nick#alex'
###
class Manager extends Emitter
  constructor: (@server) -> super()
  register: (key, nick, allMsg, password) -> @emit 'error', new Error 'NYI'
  join: (key, channel) -> @emit 'error', new Error 'NYI'
  part: (key, channel) -> @emit 'error', new Error 'NYI'
  say: (key, destination, message) -> @emit 'error', new Error 'NYI'
  send: (key, command, args...) -> @emit 'error', new Error 'NYI'
  disconnect: (key) -> @emit 'error', new Error 'NYI'
  _emitUser: (event, key, args...) ->
    @emit event, key, args...
    @emit event + '#' + key, args...

module.exports = Manager


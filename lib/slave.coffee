{EventEmitter2} = require 'eventemitter2'
Manager = require './base'
irc = require 'irc'

class Slave extends Manager
  constructor: (server) ->
    super server
    @clients = {}

  register: (username, allMsg, password) ->
    return if @clients[username]?
    options = if password? then {password: password} else {}
    client = new irc.Client @server, username, options
    @clients[username] = client
    client.on 'error', @_handleError.bind this, username
    client.on 'netError', @_handleError.bind this, username
    client.on (if allMsg then 'message' else 'pm'), (from, to, msg) =>
      obj = 
        to: to
        from: from
        msg: msg
      @emit 'message', username, obj
    client.on 'nick', (old, newNick) =>
      @emit 'nick', username, newNick, old
    client.once 'registered', =>
      @emit 'registered', username
      @emit 'nick', username, client.nick, null

  join: (username, channel) ->
    return if not @clients[username]?
    @clients[username].join channel

  say: (username, to, msg) ->
    return if not @clients[username]?
    @clients[username].say to, msg

  disconnect: (username) ->
    return if not @clients[username]?
    @clients[username].removeAllListeners()
    @clients[username].disconnect()
    delete @clients[username]

  _handleError: (username, e) ->
    @disconnect username
    @emit 'disconnect', username, e

module.exports = Slave


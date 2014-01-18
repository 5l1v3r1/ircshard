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
    
    # allMsg should only be used for bot snooping accounts
    if allMsg
      client.on 'names', (channel, users) =>
        for user of users
          @_emitUser 'enter', username, channel, user
      client.on 'part', (channel, who, reason) =>
        @_emitUser 'exit', username, channel, who
      client.on 'join', (channel, who) =>
        @_emitUser 'enter', username, channel, who
      client.on 'message', (from, to, msg) =>
        obj = to: to, from: from, msg: msg
        @_emitUser 'message', username, obj
    else
      client.on 'pm', (from, msg) =>
        obj = to: client.nick, from: from, msg: msg
        @_emitUser 'message', username, obj
    
    client.on 'nick', (old, newNick) =>
      @_emitUser 'nick', username, newNick, old
    
    client.once 'registered', =>
      @_emitUser 'registered', username
      @_emitUser 'nick', username, client.nick, null

  join: (username, channel) ->
    return if not @clients[username]?
    @clients[username].join channel

  part: (username, channel) ->
    return if not @clients[username]?
    @clients[username].part channel, 'User left'

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
    @_emitUser 'disconnect', username, e

module.exports = Slave


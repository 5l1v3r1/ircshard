{EventEmitter2} = require 'eventemitter2'
Manager = require './base'
irc = require 'irc'
assert = require 'assert'

class Slave extends Manager
  constructor: (server) ->
    super server
    @clients = {}

  register: (username, allMsg, password) ->
    assert typeof username is 'string', 'invalid username'
    assert not allMsg? or typeof allMsg is 'boolean', 'invalid allMsg'
    assert not password? or typeof password is 'string', 'invalid password'
    
    return if @clients[username]?
    options = if password? then {password: password} else {}
    client = new irc.Client @server, username, options
    @clients[username] = client
    client.on 'error', @_handleError.bind this, username
    client.on 'netError', @_handleError.bind this, username
    
    client.on 'names', (channel, users) =>
      for user of users
        @_emitUser 'enter', username, channel, user
      @_emitUser 'nicklist', username, channel, Object.keys users
    client.on 'part', (channel, who, reason) =>
      @_emitUser 'exit', username, channel, who
    client.on 'join', (channel, who) =>
      @_emitUser 'enter', username, channel, who
    
    # allMsg should only be used for bot snooping accounts
    if allMsg
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
    assert typeof username is 'string'
    assert typeof channel is 'string'
    return if not @clients[username]?
    @clients[username].join channel

  part: (username, channel) ->
    assert typeof username is 'string'
    assert typeof channel is 'string'
    return if not @clients[username]?
    @clients[username].part channel, 'User left'

  say: (username, to, msg) ->
    assert typeof username is 'string'
    assert typeof to is 'string'
    assert typeof msg is 'string'
    return if not @clients[username]?
    @clients[username].say to, msg

  disconnect: (username) ->
    assert typeof username is 'string'
    return if not @clients[username]?
    @clients[username].removeAllListeners()
    @clients[username].disconnect()
    delete @clients[username]

  _handleError: (username, e) ->
    assert typeof username is 'string'
    @disconnect username
    @_emitUser 'disconnect', username, e

module.exports = Slave


{EventEmitter2} = require 'eventemitter2'
Manager = require './base'
irc = require 'irc'
assert = require 'assert'

class Slave extends Manager
  constructor: (server) ->
    super server
    @clients = {}

  register: (key, nick, allMsg, password) ->
    assert typeof key is 'string', 'invalid key'
    assert typeof nick is 'string', 'invalid nick'
    assert not allMsg? or typeof allMsg is 'boolean', 'invalid allMsg'
    assert not password? or typeof password is 'string', 'invalid password'
    
    return if @clients[key]?
    options = if password? then {password: password} else {}
    options.autoRejoin = false
    options.userName = key
    options.realName = key
    options.retryCount = 0
    client = new irc.Client @server, nick, options
    @clients[key] = client
    
    # these are non-fatal errors so we'll ignore them
    # client.on 'error', @_handleError.bind this, key
    
    client.on 'netError', @_handleError.bind this, key
    client.on 'abort', @_handleError.bind this, key
    
    client.on 'names', (channel, users) =>
      @_emitUser 'nicklist', key, channel, Object.keys users
    client.on 'part', (channel, who) =>
      @_emitUser 'exit', key, channel, who
    client.on 'kick', (channel, who) =>
      @_emitUser 'exit', key, channel, who
    client.on 'join', (channel, who) =>
      @_emitUser 'enter', key, channel, who
    client.on 'kill', (who) =>
      @_emitUser 'kill', key, who
    
    # allMsg should only be used for bot snooping accounts
    if allMsg
      client.on 'message', (from, to, msg) =>
        obj = to: to, from: from, msg: msg
        @_emitUser 'message', key, obj
    else
      client.on 'pm', (from, msg) =>
        obj = to: client.nick, from: from, msg: msg
        @_emitUser 'message', key, obj
    
    client.on 'nick', (old, newNick) =>
      @_emitUser 'nick', key, newNick, old
    
    client.once 'registered', =>
      @_emitUser 'registered', key
      @_emitUser 'nick', key, client.nick, null

  join: (key, channel) ->
    assert typeof key is 'string', 'invalid key'
    assert typeof channel is 'string', 'invalid channel'
    return if not @clients[key]?
    @clients[key].join channel

  part: (key, channel) ->
    assert typeof key is 'string', 'invaild key'
    assert typeof channel is 'string', 'invalid channel'
    return if not @clients[key]?
    @clients[key].part channel, 'User left'

  say: (key, to, msg) ->
    assert typeof key is 'string', 'invalid key'
    assert typeof to is 'string', 'invalid to'
    assert typeof msg is 'string', 'invalid msg'
    return if not @clients[key]?
    @clients[key].say to, msg

  send: (key, command, args...) ->
    assert typeof key is 'string', 'invalid key'
    assert typeof command is 'string', 'invalid command'
    return if not @clients[key]?
    @clients[key].send command, args...

  disconnect: (key) ->
    assert typeof key is 'string', 'invalid key'
    return if not @clients[key]?
    @clients[key].removeAllListeners()
    @clients[key].disconnect 'Client disconnected'
    delete @clients[key]

  _handleError: (key, e) ->
    assert typeof key is 'string'
    @disconnect key
    @_emitUser 'disconnect', key, e

module.exports = Slave


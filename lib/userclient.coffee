{EventEmitter} = require 'events'
assert = require 'assert'

MAX_QUEUE_MESSAGE = 10
JOIN_TIMEOUT = 20000
REJOIN_TIMEOUT = 2000
RECONNECT_TIMEOUT = 2000

###
This class provides a mechanism for interacting with a particular
user account on IRC.  Essentially, here's how the connection chain
works out if you use UserClients:

[UserClient] -> Manager -> [irc.Client]

The UserClient will automatically maintain a user's IRC connection,
queue messages and join commands until they can be sent, and emit
appropriate useful events.  These events are:

'message'
- Arguments: (object) where object has `to`, `from` and `msg` keys
- Description: when this is called, the user has either been pm'd or
               a message has been sent in one of their channels.

'nick'
- Arguments: (newNick, oldNick)
- Description: called only when the user's nick gets changed or updated.

'enter'
- Arguments: (channel)
- Description: purely informational; this user has joined a channel

'exit'
- Arguments: (channel)
- Description: this user has left a channel

'disconnect'
- Arguments: ()
- Description: indicates that the client has been disconnected and is
               going to attempt a reconnect.

'registered'
- Arguments: ()
- Description: indicates that the client has connected to the server.

'debug'
- Arguments: (message)
- Description: a receiver of this can log it as they choose

A UserClient can be controlled through a few, very simple methods:

disconnect(deregister = true)
- Description: disconnects a UserClient and never sends events again.
               if `deregister` is false, the UserClient will not
               tell the underlying Manager to disconnect the IRC user.

join(channel)
- Description: either joins the channel or queues it to be joined ASAP

part(channel)
- Description: leave the channel if in it, and remove any queued joins to it

say(to, msg)
- Description: send (or queue) a message. If the recipient is a channel,
               the channel will be joined before the message is sent.

###
class UserClient extends EventEmitter
  constructor: (@manager, @key, @reqNick, @allMsg, @password) ->
    @wantChannels = []
    @rejoinTimers = {}
    @joinedChannels = []
    @pendingMessages = {}
    @pendingPMs = []
    @nick = null
    @registered = false
    @reconnectTimer = null
    
    @_configureEvents()
    @_disconnect()
    @_reconnect()
  
  disconnect: (deregister = true) ->
    assert @manager?, 'no longer connected'
    @_destroyEvents()
    @_disconnect() if deregister
    @manager = null
    @password = null
    @_cancelJoinTimeouts()
    if @reconnectTimer?
      clearTimeout @reconnectTimer
      @reconnectTimer = null
  
  _reconnect: ->
    @reconnectTimer = null
    @manager.register @key, @reqNick, @allMsg, @password

  _disconnect: ->
    @manager.disconnect @key
  
  _debug: (str) -> @emit 'debug', str
  
  # Joining Channels #
  
  join: (_channel) ->
    assert @manager?, 'no longer connected'
    channel = _channel.toLowerCase()
    return if channel in @wantChannels
    @wantChannels.push channel
    @_joinWanted channel if @registered
  
  part: (_channel) ->
    assert @manager?, 'no longer connected'
    channel = _channel.toLowerCase()
    return if (index = @wantChannels.indexOf channel) < 0
    @wantChannels.splice index, 1
    if @rejoinTimers[channel]?
      clearTimeout @rejoinTimers[channel]
      delete @rejoinTimers[channel]
    if (index = @joinedChannels.indexOf channel) >= 0
      @joinedChannels.splice index, 1
    @manager.part @key, channel
  
  _joinAllWanted: ->
    for chan in @wantChannels
      @_joinWanted chan
  
  _joinWanted: (channel) ->
    @manager.join @key, channel
    
    # setup the join timeout
    cb = @_joinTimeout.bind this, channel
    timeout = setTimeout cb, JOIN_TIMEOUT
    clearTimeout x if (x = @rejoinTimers[channel])?
    @rejoinTimers[channel] = timeout
  
  _joinTimeout: (channel) ->
    delete @rejoinTimers[channel]
    @_joinWanted channel
  
  _cancelJoinTimeouts: ->
    for channel, timeout of @rejoinTimers
      clearTimeout timeout
    @rejoinTimers = {}
  
  _handleEnter: (_channel, who) ->
    return @_debug 'enter but not registered' if not @registered?
    return if who.toLowerCase() isnt @nick
    
    channel = _channel.toLowerCase()
    
    if not channel in @wantChannels
      @_debug @key + ' ended up in unwanted channel ' + channel
      return @manager.part @key, channel
    
    # check for duplicate
    if channel in @joinedChannels
      return @_debug 'extraneous enter call ' + @key + ':' + channel

    # remove the joining timer and push the channel
    if (timer = @rejoinTimers[channel])?
      clearTimeout timer
      delete @rejoinTimers[channel]
    @joinedChannels.push channel
    
    @emit 'enter', channel
    
    # send all our pending messages
    messages = @pendingMessages[channel]
    delete @pendingMessages[channel]
    for msg in messages ? []
      @say channel, msg
  
  _handleExit: (_channel, who) ->
    return @_debug 'exit but not registered' if not @registered?
    return if who.toLowerCase() isnt @nick
    
    # get the channel
    channel = _channel.toLowerCase()
    if (index = @joinedChannels.indexOf channel) < 0
      return @_debug 'extraneous exit call ' + @key + ':' + channel
    @joinedChannels.splice index, 1
    
    @emit 'exit', channel
    
    # rejoin after a timeout if it's in our wanted
    if channel in @wantChannels
      cb = @_joinTimeout.bind this, channel
      @rejoinTimers[channel] = setTimeout cb, REJOIN_TIMEOUT
  
  # Messages #
  
  say: (_to, msg) ->
    assert @manager?, 'no longer connected'
    to = _to.toLowerCase()
    chanPref = ['#', '&']
    
    # send a PM
    if to[0] not in chanPref
      if @registered
        @manager.say @key, to, msg
      else
        @pendingPMs.push to: to, msg: msg
        if @pendingPMs.length > MAX_QUEUE_MESSAGE
          sliceOff = @pendingPMs.length - MAX_QUEUE_MESSAGE
          @_debug 'slicing ' + sliceOff + ' from PM queue for ' + @key
          @pendingPMs.splice 0, sliceOff
      return
    
    # send a channel message if we're in it
    if to in @joinedChannels
      return @manager.say @key, to, msg
    
    # push the message to the pending queue if we're not in it
    @pendingMessages[to] ?= []
    @pendingMessages[to].push msg
    if @pendingMessages[to].length > MAX_QUEUE_MESSAGE
      sliceOff = @pendingMessages[to].length - MAX_QUEUE_MESSAGE
      @_debug 'slicing ' + sliceOff + ' from ' + to + ' for ' + @key
      @pendingMessages[to].splice 0, sliceOff
    @join to

  _sendPendingPMs: ->
    [list, @pendingPMs] = [@pendingPMs, []]
    for msg in list
      @say msg.to, msg.msg
  
  _handleMessage: (obj) ->
    @emit 'message', obj
  
  # General Handlers #
  
  _handleRegistered: ->
    @registered = true
    @_joinAllWanted()
    @_sendPendingPMs()
    @emit 'registered'
  
  _handleDisconnect: ->
    @_cancelJoinTimeouts()
    @joinedChannels = []
    @registered = false
    @nick = null
    @reconnectTimer = setTimeout @_reconnect.bind(this), RECONNECT_TIMEOUT
    @emit 'disconnect'
  
  _handleNick: (_newNick, _oldNick) ->
    newNick = _newNick.toLowerCase()
    oldNick = _oldNick?.toLowerCase?()
    if oldNick is @nick or not oldNick?
      [@nick, old] = [newNick, @nick]
      @emit 'nick', @nick, old
  
  # Event Configuration #
  
  _configureEvents: ->
    @boundListeners = {}
    @boundListeners['registered'] = @_handleRegistered.bind this
    @boundListeners['disconnect'] = @_handleDisconnect.bind this
    @boundListeners['message'] = @_handleMessage.bind this
    @boundListeners['nick'] = @_handleNick.bind this
    @boundListeners['enter'] = @_handleEnter.bind this
    @boundListeners['exit'] = @_handleExit.bind this
    for event, listener of @boundListeners
      name = event + '#' + @key
      @manager.on name, listener
  
  _destroyEvents: ->
    for event, listener of @boundListeners
      name = event + '#' + @key
      @manager.removeListener name, listener
    @boundListeners = []

module.exports = UserClient

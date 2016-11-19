App.block_info = App.cable.subscriptions.create "BlockInfoChannel",
  connected: ->
    console.info 'connected to block_info channel'
    # Called when the subscription is ready for use on the server

  disconnected: ->
    # Called when the subscription has been terminated by the server

  received: (data) ->
    # Called when there's incoming data on the websocket for this channel
    console.info 'data updated'
    Turbolinks.visit location.toString()

  ping: (message) ->
    # Turbolinks.visit location.toString()
    @perform 'ping', message: message

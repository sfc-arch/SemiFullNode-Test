# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
class BlockInfoChannel < ApplicationCable::Channel
  def subscribed
    stream_from :block_info
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def ping(data)
    ActionCable.server.broadcast :block_info, message: data['message']
  end
end

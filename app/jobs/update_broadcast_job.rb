class UpdateBroadcastJob < ApplicationJob
  queue_as :default

  def perform(arg)
    ActionCable.server.broadcast :block_info, { id: arg.id }
  end
end

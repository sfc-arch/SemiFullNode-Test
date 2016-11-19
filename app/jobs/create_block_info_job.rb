class CreateBlockInfoJob < ApplicationJob
  queue_as :default

  def perform(block_hash)
    begin
      block = Block.find_by!(merkle_root_hash: block_hash)
      BlockInfo.create!({
          merkle_root_hash: block.merkle_root_hash,
          height: block.height,
          looked_up_rate: 0.0,
          deletable: false
      })
    rescue => e
      puts e
      puts e.backtrace
    end
  end
end

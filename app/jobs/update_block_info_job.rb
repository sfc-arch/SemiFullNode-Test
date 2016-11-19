class UpdateBlockInfoJob < ApplicationJob
  queue_as :default

  def perform(block_hash)
    begin
      blockinfo = BlockInfo.find_by!(merkle_root_hash: block_hash)
      block = Block.find_by!(merkle_root_hash: block_hash)
      info = [
          block.transactions.inject(true) do |sum, tx|
            sum && (tx.referred_bys.count == tx.pay_tos.count)
          end,
          block.transactions.inject(0) do |sum, tx|
            sum += tx.referred_bys.count
          end,
          block.transactions.inject(0) do |sum, tx|
            sum += tx.pay_tos.count
          end
      ]
      blockinfo.update!({
          looked_up_rate: (info[1].rationalize / info[2].rationalize).to_f,
          deletable: info[0]
      })
    rescue => e
      puts e
      puts e.backtrace
    end
  end
end

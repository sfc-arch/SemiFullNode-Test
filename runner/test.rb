module Neo4j::ActiveNode::ClassMethods
  def ===(other)
    self == other.class
  end
end

class Neo4j::ActiveRel::RelatedNode
  def is_a?(object)
    object === self
  end
end


begin
  ## Create Genesis Block
  genesis = Block.create!({
      height: 0,
      nonce: 0,
      timestamp: DateTime.now.new_offset(0),
      merkle_root_hash: Blockchain::Digest.sha256d("Genesis Block")
  })
  CreateBlockInfoJob.perform_later genesis.merkle_root_hash

  index = 1
  old_key = Blockchain::Wallet::KeyGen.key_pair(128)
  old_wallet = Wallet.create!(public_key: old_key.public_key, private_key: old_key.private_key)
  old_tx = old_wallet.new_transaction do |tx|
    tx.add_payment(to: old_wallet, amount: 10000.0)
    # tx.set_fee
  end
  txs = [old_tx]
  loop do
    puts index if index%10 == 0

    new_wallet =
        if index > 10 #&& (Random.rand * 100).floor <= 95
          begin
            reused_wallet = Wallet.all.to_a.sample  # select randomly from existing wallet
            raise if reused_wallet == old_wallet
          rescue
            retry
          else
            # p "reused!"
            reused_wallet
          end
        else
          new_key = Blockchain::Wallet::KeyGen.key_pair(128)
          Wallet.create!(public_key: new_key.public_key, private_key: new_key.private_key)
        end
    new_tx = old_wallet.pay(
        to: new_wallet,
        amount: (old_wallet.amount - 0.0005) * (Random.rand*10000).floor/10000.0,
        tx_fee: 0.0005
    )

    #puts "- #{new_tx.refers_tos.count} #{new_tx.input_size} #{new_tx.pay_tos.count} #{new_tx.output_size}"

    txs << new_tx
    if index % 20 == 0
      old_wallet.mine!(txs)
      txs.clear
    end

    #break if index >= 200

    old_wallet, old_tx = new_wallet, new_tx
    index += 1
  end

  puts "End!"
rescue => e
  puts e
  puts e.backtrace
end

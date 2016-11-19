require 'open3'

class Block
  include Neo4j::ActiveNode

  ## Columns
  property :merkle_root_hash, type: String, constraint: :unique, null: false
  property :height, type: Integer, index: :exact
  property :nonce, type: Integer
  property :difficulty_target, type: Integer
  property :fee, type: Float
  property :timestamp, type: DateTime
  property :state, type: Integer, default: 0 # Enum

  ## Validations
  validates_presence_of :merkle_root_hash

  ## Associations
  has_many :out, :transactions, model_class: :Transaction, rel_class: :Ownership, unique: true, dependent: :destroy
  has_one  :out, :parent, model_class: :Block, rel_class: :Chaining
  has_many :in,  :children,  model_class: :Block, rel_class: :Chaining
  has_one  :in,  :owner, model_class: :Wallet, rel_class: :Ownership

  ## Enums
  enum state: {
      norm: 0,
      confirmed: 1,   # 深さ6以上
      mine_usable: 2, # 深さ20以上
      old: 3          # 深さ30以上
  }

  ## Hooks
  # after_create :change_state_of_ancestors

  ## 定数
  TARGET = 12  # bits


  # Use to parse JSON
  # {
  #     "merkle_root_hash": "712eb5e27aeae826872c961f8435fe07f5fa8fe929ae8a44ced8cfe338a94262",
  #     "height": 1,
  #     "nonce": 2678222,
  #     "difficulty_target": 20,
  #     "fee": 0.4,
  #     "timestamp": "2016-11-14T05:21:53.000+00:00",
  #     "transactions": [
  #         "b73d9b7d50784308b5e2217ca0aa04fe8cde7afd7a251712cdeff0361e8963f4",
  #         "7638c9a07d6fdb4c0fb8ea4178d0d53593ec5170eaa99678c9560ec3d281c619"
  #     ]
  # }
  # こんなものが送られてくる
  def self.create_from_json(json_str)
    ## とりあえずJSONに
    json = JSON.parse json_str
    b = Block.new

    ## すでにあるならいらない
    raise BlockAlreadyExistsError if Block.find_by(merkle_root_hash: json["merkle_string_hash"])
    b.check_nonce!(
        hash: json["merkle_root_hash"],
        nonce: json["nonce"],
        target_bits: json["difficulty_target"]
    )

    ## Check if transactions are all right
    txs = json["transactions"].map do |tx_hash|
      tx = Transaction.find_by(hash_value: tx_hash)
      if tx
        b.check_transaction!(tx)    # raises if something wrong
        tx
      else
        raise "Tx doesn't exist!"
      end
    end

    ## TODO: Blockの参照先を見る
    parent_block = Block.find_by(merkle_root_hash: json["previous_block_hash"])
    ## TODO: heightの確認
    ## TODO: feeの確認(いるか？)

    ## 作成
    block = Block.create!({
        merkle_root_hash: json["merkle_root_hash"],
        height: json["height"],
        nonce: json["nonce"],
        difficulty_target: json["difficulty_target"],
        fee: json["fee"],
        timestamp: DateTime.parse(json["timestamp"])
    })
    block.parent = parent_block
    txs.each_with_index do |tx, i|
      Ownership.create!(from_node: block, to_node: tx, index: i)
    end
    change_state_of_ancestors
    ## validate size
    raise "number of transactions are different!" unless block.transactions.count == json["transactions"].count

    return block
  rescue => err
    puts err
    puts err.backtrace[0..7]
    block.destroy
    return false
  end

  # to Ruby hash
  def to_hash
    {
        merkle_root_hash: self.merkle_root_hash,
        previous_block_hash: self.parent.merkle_root_hash,
        height: self.height,
        nonce: self.nonce,
        difficulty_target: self.difficulty_target,
        fee: self.fee,
        timestamp: self.timestamp.to_s,
        transactions: self.transactions.each_with_rel.sort_by{|tx, ref| ref.index}.map {|tx, rel| tx.hash_value }
    }
  end

  # Convert to JSON
  def to_json
    self.to_hash.to_json
  end


  # マイニングするトランザクションの検証
  #   - ちゃんとロックされてるか
  #   - 他のブロックに含まれていないか
  #
  def check_transaction!(tx)
    # txがvalidかチェックする
    a = case
        when !tx.locked?
          "Not locked"
        when tx.enblockened_by.present?
          "Already Owned By Block"
        end
    error = "Error in Transaction Check: #{tx.hash_value} "
    raise error + a if a
  end

  def calc_fee(txs)
    txs.inject(0.0) do |sum, tx|
      sum += tx.fee
    end
  end

  def calc_merkle_root(txs)
    hash_array = txs.map do |tx|
      if tx.is_a? Transaction
        tx.hash_value
      else
        Transaction.find_by!(hash_value: tx).hash_value
      end
    end
    res = calc_merkle_tree(hash_array)
    raise 'something wrong' unless res.length == 1
    return res.first
  end

  # Calculates nonce
  def calc_nonce(hash:, target_bits: 20)
    o, e, s = Open3.capture3 "./crystal/calc-nonce #{hash} #{target_bits}"
    raise 'Nonce Calculation has not ended correctly' unless s.success?
    return o.split("\n")[1]
  end

  # Checks if nonce is right
  def check_nonce!(hash:, nonce:, target_bits: 20)
    digest = Digest::SHA256.hexdigest(hash.to_s + nonce.to_s)
    raise BlockError "Block nonce is wrong!" unless digest.to_i(16) < 2 ** (256 - target_bits)
    true
  end

  def change_state_of_ancestors
    self.parent&.parent&.parent&.parent&.parent&.parent&.confirmed!
    self.parent&.parent&.parent&.parent&.parent&.
        parent&.parent&.parent&.parent&.parent&.
        parent&.parent&.parent&.parent&.parent&.mine_usable!
    self.parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.
        parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.
        parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.parent&.old!
  end


  ## Error Classes
  class BlockError < StandardError
  end

  class BlockAlreadyExistsError < BlockError
  end

  private

  def calc_merkle_tree(array)
    if array.length == 1
      return array
    end

    array << array.last if array.count.odd?
    array = array.each_slice(2).map do |pair|
      # p pair
      Blockchain::Digest.sha256d(pair.first + pair.last)
    end
    calc_merkle_tree array
  end
end

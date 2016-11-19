# {
#     "version": "1.0.0",
#     "input_size": 1,
#     "inputs": [
#         {
#             "prev_hash": "00000000000",
#             "prev_index": 0,
#             "script_length": 230,
#             "script": {
#                 "signature": "7c33a427e67ba3d4faead818975ee4511cafc6d657bc8e0b4084f16f5778bcf2066e7dc34fa24dc520738c064891e270c557fe8eeccc731345104e347a431476",
#                 "public_key": "\u0003878cade4c9215ade91336e895a6e20343056bc5610039469b4dac1e2c708c2de"
#             }
#         }
#     ],
#     "output_size": 1,
#     "outputs": [
#         {
#             "amount": 2000,
#             "address": "b15f9ea52c4f6e8b1a985235f87a028e104c76a3"
#         }
#     ],
#     "timestamp": "2016-11-03T17:29:20+09:00"
# }self.refers_tos.each_rel.sort_by{|rel| rel.id}

# require_relative '../../blockchain/transaction'

class Transaction
  include Neo4j::ActiveNode

  ## Columns
  property :hash_value, type: String, index: :exact  # トランザクションには使わない。検索用、sha256d
  property :timestamp, type: DateTime, null: false
  property :fee, type: Float, default: 0.0
  # property :raw_string, type: String    # なくそう
  property :input_size, type: Integer, default: 0
  property :output_size, type: Integer, default: 0
  property :locked, type: Boolean, default: false, null: false

  #serialize :raw_string

  ## Validations
  validates_presence_of :timestamp
  validates_inclusion_of :locked, in: [true, false]

  ## Associations
  has_one  :in,  :wallet, origin: :transactions, unique: true
  has_many :out, :refers_tos, rel_class: :RefersTo, model_class: :Transaction, unique: true
  has_many :in,  :referred_bys, rel_class: :RefersTo, model_class: :Transaction, unique: true
  has_many :out, :pay_tos, rel_class: :Payment, model_class: :Wallet, unique: true
  # has_one  :in,  :enblockened_by, model_class: :Block, rel_class: :Ownership
  has_many  :in,  :enblockened_by, origin: :transactions, model_class: :Block

  ## Scopes
  scope :locked, -> {where(locked: true)}
  scope :not_locked, -> {where(locked: false)}

  ## Class Methods

  # no need to state timestamp.
  def initialize(**args)
    unless args[:timestamp]
      args[:timestamp] = DateTime.now.new_offset(0)
    end

    super(args)
  end

  # create a {Transaction} Object from given JSON string.
  # @param json_str [String] JSON string to parse. Will NOT check.
  # @return [Transaction] a new Transaction object.
  # @raise [TransactionVerifyError] if JSON was wrong
  def self.create_from_json(json_str)
    json = JSON.parse(json_str)

    ## Validation
    # 受信したトランザクションの検証
    #   1. トランザクションの構文とデータ構造はただしいか => 作れれば正しいはず
    #   2. インプットとアウトプットは共に空ではないか
    #   3. アウトプットvalueは許されている範囲内か
    #   4. coinbaseはリレーされるべきでない
    #   5. メインブランチブロックチェーンもしくはトランザクションプールにそのTxがあれば拒否する
    #   6. インプットの参照先がトランザクションプールにあるやつのそれと被ってたら拒否
    #   7. 参照先がなければオーファント  => 特に分ける必要はないのかなって
    #   8. 参照しているアウトプットは未使用か
    #   9. input_amount > output_amountか
    raise TransactionVerifyError.new "input or output is nil!" if json[:input_size] == 0 || json[:output_size] == 0      # 2
    raise TransactionVerifyError.new "input_size and inputs' size doesn't match!" unless json[:input_size] == json[:inputs].size       # 1
    raise TransactionVerifyError.new "output_size and outputs' size doesn't match!" unless json[:output_size] == json[:outputs].size   # 1

    # calculate hash_value
    hash_val = Blockchain::Digest.sha256d json_str
    raise TransactionVerifyError.new "transaction already exists in DB!" if Transaction.find_by(hash_value: hash_val)    # 5 (hashでみればいいかな)

    # create Transaction
    this = Transaction.create!(
        hash_value: hash_val,
        timestamp: DateTime.parse(json[:timestamp]).new_offset(0),
        input_size: json[:input_size].to_i,
        output_size: json[:output_size].to_i
    )

    # Calculate fee while creating Associations

    input_sum = json[:inputs].inject(0.0) do |sum, input|
      # look up for referring tx. raise if unavailable # TODO: place into pool if no referring tx
      referring_tx = Transaction.find_by!(hash_value: input[:prev_hash])
      index = input[:prev_index].to_i
      # Validate
      if referring_tx.referred_bys.each_rel.any? do |ref|
           ref.index = index
         end
        raise TransactionVerifyError.new "transaction reffering to the output already exists!"  # 6, 8
      end
      RefersTo.create!(from_node: this, to_node: referring_tx, index: index)
      sum += referring_tx.payments[index].amount
    end

    output_sum = json[:outputs].each_with_index.inject(0.0) do |sum, (output, index)|
      # look up for target wallet. raise if not found. # TODO: find_or_create_by!
      receiver = Wallet.find_by!(address: output[:address])
      amount = output[:amount].to_f
      Payment.create!(from_node: this, to_node: receiver, amount: amount, index: index)
      sum += amount
    end

    fee = input_sum - output_sum
    raise TransactionVerifyError.new "fee is negative!" if fee < 0.0    # 9

    # update with calculated fee
    this.update!(fee: fee)
    return this
  end


  ## Instance Methods

  # 便利メソッド for adding references to tx.
  # @param target [String | Transaction] Transaction (or the hash of it) which is sending money to you
  # @param index [Integer] the index of the tx's output
  # @return [RefersTo]
  def add_reference(target:, index:)
    disallow_if_locked!
    raise TypeError unless target.is_a? Transaction or target.is_a? String
    raise TypeError unless index.is_a? Integer

    target_transaction =
        case target
        when String
          Transaction.find_by!(hash_value: target)
        when Transaction
          target
        else
          raise "argument to must be a String or a Transaction, but #{target.class} given."
        end

    # TODO: 自分のUTXOなのかの検証が必要！

    ref = RefersTo.create!(from_node: self, to_node: target_transaction, index: index)
    self.input_size = self.refers_tos.each_rel.count
    self.save!

    return ref
  end

  # 便利メソッド for adding payments to tx.
  # @param to [String | Wallet] Wallet address or wallet itself
  # @return [Payment]
  def add_payment(to:, amount:)
    disallow_if_locked!
    raise ArgumentError unless amount.is_a? Float
    target_wallet =
        case to
        when String
          Wallet.find_by!(address: to)
        when Wallet
          to
        else
          raise "argument to must be a String or a Wallet, but #{to.class} given."
        end

    self.output_size += 1
    self.save!
    Payment.create!(from_node: self, to_node: target_wallet, amount: amount, index: self.output_size - 1)
  end

  # 入力の合計
  def input_amount
    self.refers_tos.each_rel.inject(0.0) do |sum, ref|
      sum += ref.amount
    end
  end

  # 出力の合計
  def output_amount
    self.pay_tos.each_rel.inject(0.0) do |sum, payment|
      sum += payment.amount
    end
  end

  # Feeを計算して代入する
  def set_fee
    self.fee = (input_amount.rationalize - output_amount.rationalize).to_f
    self.save!
    return self.fee
  end

  def lock!
    self.update!(locked: true)
  end

  # Encodes into hash.
  #
  # {
  #     :version => "1.0.0",
  #     :input_size => 1,
  #     :inputs => [
  #         {
  #             :prev_hash => nil,
  #             :prev_index => 0
  #         }
  #     ],
  #     :output_size => 1,
  #     :outputs => [
  #         {
  #             :amount => 1.1,
  #             :address => "72ahXGLRsCch1EgXEyFWkuHczPeTFy8B"
  #         }
  #     ],
  #     :timestamp=>Tue, 08 Nov 2016 09:26:28 +0000
  # }
  #
  # @return [Hash]
  def to_hash
    # TODO: 先に雛形作ってハッシュ値を計算してSigScriptを作ってRefersToに保存しないといけない気がする

    ## id順に
    inputs = self.refers_tos.each_rel.sort_by{|rel| rel.id}
    outputs = self.pay_tos.each_rel.sort_by{|payment| payment.id}
    unless inputs.size == self.input_size && outputs.size == self.output_size
      raise 'inputs/outputs size does not match DB'
    end

    hash = {
        version: "1.0.0",
        input_size: self.input_size,
        inputs: inputs.map do |input|
          input.to_hash
        end,
        output_size: self.output_size,
        outputs: outputs.map do |output|
          output.to_hash
        end,
        timestamp: self.timestamp
    }

    # TODO: check hash value with self.hash_value

    return hash
  end

  def to_json
    JSON(self.to_hash)
  end


  def delete
    disallow_if_locked!
    super
  end


  ## Errors

  class TransactionAlreadyLockedError < StandardError
  end

  class TransactionVerifyError < StandardError
    def initialize(msg)
      super "Verify failed because: #{msg}"
    end
  end

  private
  def disallow_if_locked!
    if self.locked?
      raise TransactionAlreadyLockedError.new 'You are not allowed to edit node after confirmation.'
    end
  end
end

# require 'bundler'
# Bundler.setup
require 'base58'
#
# require_relative '../../blockchain/wallet/keygen'
# require_relative '../../blockchain/wallet/signature'

class Wallet
  include Neo4j::ActiveNode

  ## Columns
  property :address, type: String, null: false, constraint: :unique
  property :version, type: Float, default: 0.1
  property :private_key, type: String, constraint: :unique
  property :public_key, type: String, constraint: :unique

  ## Validations

  ## Associations
  has_one  :in,  :owner, origin: :wallets, model_class: :User
  has_many :out, :transactions, rel_class: :Ownership, model_class: :Transaction
  has_many :in,  :incomes, origin: :pay_tos, model_class: :Transaction
  has_many :out, :blocks, model_class: :Block, rel_class: :Ownership, unique: true

  ## Static Values
  ADDRESS_HEADER = "7"

  ## Class Methods
  def initialize(**args)
    if (pubkey = args[:public_key]) && args[:address].nil?
      args[:address] = generate_wallet_address(pubkey)
    end

    super(args)
  end

  ## Instance Methods
  def key_hash
    str1 = Base58.decode(self.address[1..-1]).to_s(16)
    checksum = str1[-4..-1]
    key_hash = str1[0...-4]
    if Blockchain::Digest.sha256d(ADDRESS_HEADER + key_hash)[0..3] == checksum
      key_hash
    else
      false
    end
  end

  # Create new transaction. Give block like File#open. Will close at end of block.
  def new_transaction(&block)
    transaction = Transaction.create!
    self.transactions << transaction

    if block
      block.call(transaction)
      sign(transaction)
    end

    return transaction
  end

  # Signs all inputs of given transaction, and locks up the transaction.
  def sign(transaction)
    raise TypeError "transaction must be a Transaction, but #{transaction.class} given." unless transaction.is_a? Transaction
    raise NotMyTransactionError.new 'tx not yours!' unless transaction.wallet == self
    raise Transaction::TransactionAlreadyLockedError.new 'locked transaction' if transaction.locked?

    hash_orig = transaction.to_hash

    hash_values = hash_orig[:input_size].times.map do |index|
      hash = hash_orig.dup
      hash[:inputs][index][:script] = {
          address: Blockchain::Digest.hash160(self.public_key)
      }
      # calculate hash value
      hash_input = Blockchain::Digest.sha256d hash.to_json
      hash_value = Blockchain::Wallet::Signature.sign(hash_input, self.private_key)
      hash_value.encode
    end

    transaction.refers_tos.each_rel do |ref|
      ref.update!({
          signature: hash_values[ref.index],
          public_key: self.public_key
      })
    end

    transaction_hash_value = Blockchain::Digest.sha256d transaction.to_json
    transaction.update!(hash_value: transaction_hash_value)

    transaction.lock!

    return transaction
  end

  # Create a new block from wallet. you can get mining fees.
  # Use to build Blocks by passing transactions.
  #
  # @param transactions [Array[Transaction]] Transaction, or Transactions
  # @return [Block] a new block.
  def mine!(*transactions)
    new_block = Block.new

    transactions.flatten!

    # now lets create val==ues for the block and associations
    transactions = transactions.map do |tx|
      tx =
          if tx.is_a? String
            Transaction.find_by(hash_value: tx)
          elsif tx.is_a? Transaction
            tx
          else
            # next
            raise 'Block#new must be called with an array of Transactions.'
          end
      new_block.check_transaction!(tx)
      tx
    end
    fee = new_block.calc_fee(transactions)
    merkle_root_hash = new_block.calc_merkle_root(transactions)
    previous_block = Block.all.order(:height).last
    nonce = new_block.calc_nonce(hash: merkle_root_hash, target_bits: Block::TARGET)

    # add coinbase transaction to first
    cbtx = self.new_transaction do |tx|
      tx.add_payment(to: self, amount: fee + 30)
      tx.fee = 0.0
    end
    transactions.unshift(cbtx)

    # update new_block
    new_block.merkle_root_hash = merkle_root_hash
    new_block.height = previous_block.height + 1
    new_block.fee = fee
    new_block.nonce = nonce
    new_block.difficulty_target = Block::TARGET
    new_block.timestamp = DateTime.now.new_offset(0)
    # and save it
    new_block.save!

    transactions.each_with_index do |tx, index|
      Ownership.create!(from_node: new_block, to_node: tx, index: index)
    end

    new_block.parent = previous_block
    new_block.change_state_of_ancestors

    self.blocks << new_block
    # 送る
    CreateBlockInfoJob.perform_later new_block.merkle_root_hash
    return new_block
  rescue => e
    # revert if errors
    puts e
    puts e.backtrace
    new_block.destroy
    return false
  end
  alias_method :mine_new_block, :mine!

  # Gets all UXTOs in array
  # @return [Array[Payment]]
  def uxtos
    self.incomes.each_with_rel.map{|tx, rel| tx.referred_bys[rel.index] ? nil : rel}.compact
  end

  # Calculates all UXTO's amounts
  # @return [Float]
  def amount(uxtos = self.uxtos)
    uxtos.inject(0.0) do |sum, uxto|
      sum += uxto.amount
    end
  end

  # Select UXTOs to use.
  # @param pay_amount [Float]
  def select_uxtos(pay_amount, sort: :oldest)
    raise "ArgumentError"+ "You cannot pay that much!" if pay_amount > self.amount

    case sort
    when :oldest
      payments = self.uxtos.sort_by{|uxto| uxto.from_node.enblockened_by&.first&.height || Float::INFINITY}
      target = 0
      selected_from_oldest = payments.take_while {|i| target += i.amount; target-i.amount < pay_amount}
    when :biggest
      payments = self.uxtos.sort_by{|uxto| uxto.amount}.reverse
      target = 0
      selected_from_biggest = payments.take_while {|i| target += i.amount; target-i.amount < pay_amount}
    else
      raise "ArgumentError"+ "sort options should be one of :oldest, :biggest"
    end
  end

  # @param to [Wallet | String] Wallet, or the Address
  # @param amount [Float]
  # @param tx_fee [Float]
  def pay(to:, amount:, tx_fee: 0.001)
    to = Wallet.find_by!(address: to) if to.is_a? String
    raise TypeError "parameter to must be a Wallet or a Wallet address (String)." unless to.is_a? Wallet
    uxtos = self.select_uxtos(amount)
    input_sum = self.amount(uxtos)
    change = (input_sum.rationalize - amount.rationalize - tx_fee.rationalize).to_f
    # Create Tx
    tx = self.new_transaction do |tx|
      uxtos.each do |uxto|
        tx.add_reference(target: uxto.from_node, index: uxto.index)
      end
      tx.add_payment(to: to, amount: amount)
      tx.add_payment(to: self, amount: change)
      tx.set_fee
    end
    tx.refers_tos.each do |ref_tx|
      block = ref_tx.enblockened_by.first
      UpdateBlockInfoJob.perform_later block.merkle_root_hash unless block.nil?
    end
    return tx
  end


  def delete
    raise NotImplementedError
  end


  class NotMyTransactionError < StandardError
  end

  private

  def generate_wallet_address(public_key_str)
    str1 = Blockchain::Digest.hash160 public_key_str
    str2 = ADDRESS_HEADER + str1
    str3 = Blockchain::Digest.sha256d str2
    str4 = str1 + str3[0..3]
    str5 = ADDRESS_HEADER + Base58.encode(str4.to_i(16))
    return str5
  end
end

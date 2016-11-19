# Transaction 1::1 Wallet
class Payment
  include Neo4j::ActiveRel

  from_class :Transaction
  to_class   :Wallet
  type 'payment'

  # {
  #     "amount": 2000,
  #     "address": "b15f9ea52c4f6e8b1a985235f87a028e104c76a3"
  # }

  property :amount, type: Float, null: false
  property :index, type: Integer, null: false
  # property :grade, type: Integer
  # property :notes

  validates_presence_of :amount
  validates_numericality_of :amount

  # def generate_pubkeyscript(address)
  #   Blockchain::Wallet.wallet_address_to_key_hash(address)
  # end

  def to_hash
    {
        amount: self.amount,
        address: self.to_node.address
    }
  end
end

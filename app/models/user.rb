class User
  include Neo4j::ActiveNode

  ## Columns
  property :name, type: String, null: false
  property :private_key, type: String, constraint: :unique
  property :public_key, type: String, constraint: :unique
  property :seed, type: String

  ## Validations
  validates_presence_of :name, :private_key, :public_key

  ## Associations
  has_many :out, :wallets, model_class: :Wallet, rel_class: :Ownership, unique: true


  def create_wallet!
    # TODO: seedで作るように
    w = Wallet.create!(public_key: self.public_key, private_key: self.private_key)
    Ownership.create!(from_node: self, to_node: w)
    return w
  end

  # return the total of amounts the User has.
  def amount
    self.wallets.inject(0.0) do |sum, wallet|
      sum += wallet.amount
    end
  end
end

class Testnode
  include Neo4j::ActiveNode

  has_one  :out, :parent, model_class: :Testnode, rel_class: :Ownership

  after_create do
    User.create!
  end

  def self.to_a
    [true]
  end
end

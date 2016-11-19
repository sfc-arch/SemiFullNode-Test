require_relative '../../lib/blockchain/transaction'
require_relative '../../lib/blockchain/wallet'


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

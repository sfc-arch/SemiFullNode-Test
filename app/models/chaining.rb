# representing Chains of blocks
class Chaining
  include Neo4j::ActiveRel

  from_class :Block
  to_class   :Block
  type 'chained'

  # property :index, type: Integer, default: nil
  # property :grade, type: Integer
  # property :notes
  #
  # validates_presence_of :since
end

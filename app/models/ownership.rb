# representing Ownership
class Ownership
  include Neo4j::ActiveRel

  from_class :any
  to_class   :any
  type 'owns'

  property :index, type: Integer, default: nil
  # property :grade, type: Integer
  # property :notes
  #
  # validates_presence_of :since
end

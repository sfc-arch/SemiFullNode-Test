module Blockchain
  class SigScript
    def initialize(signature_str, public_key)
      @signature = signature_str
      @public_key = public_key
      @length = (@signature + @public_key).length
    end

    def to_hash
      {
          signature: @signature,
          public_key: @public_key
      }
    end
  end
end
module Blockchain
  class PubKeyScript
    def initialize(address)
      @hash = Blockchain::Wallet.wallet_address_to_key_hash(address)
      @length = @hash.length
    end

    def to_hash
      {
          length: @length,
          hash: @hash
      }
    end
  end
end
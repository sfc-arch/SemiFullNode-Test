# require 'bundler'
# Bundler.setup
require 'base58'

require_relative 'wallet/keygen'
require_relative 'wallet/signature'

module Blockchain
  class Wallet
    HEADER = "7"

    def self.generate_wallet_address(public_key_str)
      str1 = Blockchain::Digest.hash160 public_key_str
      str2 = HEADER + str1
      str3 = Blockchain::Digest.sha256d str2
      str4 = str1 + str3[0..3]
      str5 = HEADER + Base58.encode(str4.to_i(16))
    end

    def self.wallet_address_to_key_hash(address)
      str1 = Base58.decode(address[1..-1]).to_s(16)
      checksum = str1[-4..-1]
      key_hash = str1[0...-4]
      if Blockchain::Digest.sha256d(HEADER + key_hash)[0..3] == checksum
        key_hash
      else
        false
      end
    end
  end
end

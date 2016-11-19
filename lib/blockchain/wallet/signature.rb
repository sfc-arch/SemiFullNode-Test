require 'bundler'
Bundler.setup
require 'ecdsa'


module ECDSA
  class Signature
    def encode
      ECDSA::Format::SignatureBitcoinHexString.encode(self)
    end
  end

  module Format
    module SignatureBitcoinHexString
      def self.encode(signature)
        signature.r.to_s(16).rjust(64, '0') + signature.s.to_s(16).rjust(64, '0')
      end

      def self.decode(hex_string)
        raise ArgumentError if hex_string.length.odd?
        r = hex_string[0...hex_string.length/2].to_i(16)
        s = hex_string[hex_string.length/2..-1].to_i(16)
        Signature.new(r, s)
      end
    end
  end
end

module Blockchain
  class Wallet
    module Signature
      GROUP = ECDSA::Group::Secp256k1

      module_function

      def sign(target, private_key)
        raise TypeError "target must be String, but #{target.class} given" unless target.is_a? String
        digest = ::Digest::SHA256.digest(target)
        signature = nil
        private_key_int = private_key.to_i(16)
        while signature.nil?
          temp_key = 1 + SecureRandom.random_number(GROUP.order - 1)
          signature = ECDSA.sign(GROUP, private_key_int, digest, temp_key)
        end

        return signature
      end

      def decode(signature_der_string)
        ECDSA::Format::SignatureBitcoinHexString.decode(signature_der_string)
      end

    end
  end
end

require 'securerandom'

require 'bundler'
Bundler.setup
require 'ecdsa'

module ECDSA
  module Format
    module PointHexString
      GROUP = ECDSA::Group::Secp256k1

      def encode(point, opts = {})
        return "0" if point.infinity?

        if opts[:compression]
          start_byte = point.y.even? ? "\u0002" : "\u0003"
          start_byte + point.x.to_s(16).rjust(64, '0')
        else
          "\u0004" +
              point.x.to_s(16).rjust(64, '0') +
              point.y.to_s(16).rjust(64, '0')
        end
      end

      def decode(string, group = GROUP)
        raise DecodeError, 'Point octet string is empty.' if string.empty?
        case string[0].ord
        when 1
          raise DecodeError 'String Length is wrong,' unless string.length == 1
        when 2, 3
          x_string = string[1..-1]
          x = x_string.to_i(16)
          y_lsb = string[0].ord.to_i % 2
          possible_ys = group.solve_for_y(x)
          y = possible_ys.find { |py| (py % 2) == y_lsb }
          raise DecodeError, 'Could not solve for y.' if y.nil?
          point = group.new_point [x, y]
          unless group.include? point
            raise DecodeError, "Decoded point does not satisfy curve equation: #{point.inspect}."
          end
          point
        when 4
          str = string[1..-1]
          x_string = str[0...str.length/2]
          y_string = str[str.length/2..-1]
          point = group.new_point [x_string.to_i(16), y_string.to_i(16)]
          unless group.include? point
            raise DecodeError, "Decoded point does not satisfy curve equation: #{point.inspect}."
          end
          point
        else
          raise DecodeError, "Unrecognized start byte for point octet string: `#{string[0].ord}`"
        end
      end

      module_function :encode, :decode
    end
  end
end

module Blockchain
  class Wallet
    module KeyGen
      KEY_PAIR = Struct.new(:private_key, :public_key)
      GROUP = ECDSA::Group::Secp256k1

      module_function

      # Generates new private key.
      #
      # @param size_in_bits [Integer] bytes * 8
      # @return [String] private key in hex string
      def private_key(size_in_bits = 128)
        raise ArgumentError 'size must be a multiple of 8' unless size_in_bits % 8 == 0
        SecureRandom.hex(size_in_bits/8)
      end

      # Generates new public key from given private key
      #
      # @param private_key [String] private key string in hex
      # @return [String] hex string.
      def public_key(private_key)
        private_key_int = private_key.to_i(16)
        KeyGen::GROUP.generator.multiply_by_scalar(private_key_int)
      end

      def encode_public_key(key)
        ECDSA::Format::PointHexString.encode(key, compression: true)
      end

      def decode_public_key(public_key_str)
        ECDSA::Format::PointHexString.decode(public_key_str, GROUP)
      end

      # Generate new key pair.
      #
      # @param size_in_bits [Integer] bytes * 8
      # @return [String] private key in hex string
      # @return [String] encoded public key in prefix + hex string.
      def keys(size_in_bits = 128)
        privkey = private_key(size_in_bits)
        pubkey = encode_public_key public_key(privkey)
        return privkey, pubkey
      end

      # @see KeyGen#keys
      def key_pair(size_in_bits = 128)
        keys = keys(size_in_bits)
        struct = KeyGen::KEY_PAIR.new *keys
        return struct
      end
    end
  end
end

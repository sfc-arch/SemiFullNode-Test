require 'json'
require 'securerandom'
require 'digest'

# require 'bundler'
# Bundler.setup
require 'ecdsa'

require_relative './digest'
require_relative './transaction_input'
require_relative './transaction_output'
require_relative './pub_key_script'
require_relative './sig_script'

module Blockchain
  include Blockchain::Digest

  class Transaction
    def initialize
      @version = "1.0.0"  if Gem::Version.correct?("1.0.0")
      @inputs = []
      @outputs = []
      @timestamp = DateTime.now
    end
    attr_reader :inputs, :outputs

    def add_input(input)
      raise TypeError "must be a Blockchain::TransactionInput but #{input.class} was given." unless input.is_a? Blockchain::TransactionInput
      @inputs << input
      return input
    end

    def remove_input_at(index)
      @input.delete_at index
      return self
    end

    def add_output(output)
      raise TypeError "must be a Blockchain::TransactionInput but #{output.class} was given." unless output.is_a? Blockchain::TransactionOutput
      @outputs << output
      return output
    end

    def remove_output_at(index)
      @output.delete_at index
      return self
    end

    def signature
      json = self.to_json
      sign = Blockchain::Digest.sha256d json
      return sign
    end

    def validate

    end

    def to_hash
      {
          version: @version,
          input_size: @inputs.size,
          inputs: @inputs.map do |input|
            input.to_hash
          end,
          output_size: @outputs.size,
          outputs: @outputs.map {|output| output.to_hash},
          timestamp: @timestamp.iso8601
      }
    end

    def to_json
      self.to_hash.to_json
    end

  end
end

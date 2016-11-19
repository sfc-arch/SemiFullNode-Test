module Blockchain

  # Abstract base class for CLI utilities. Provides some helper methods for
  # the option parser
  #
  # @author U-dory|Todoroki (Ryo Konishi)
  # @abstract
  # @since 0.0.0
  # @attr [Types] attribute_name a full description of the attribute
  # @attr_reader [Types] name description of a readonly attribute
  # @attr_writer [Types] name description of writeonly attribute
  class TransactionOutput
    def initialize(output_amount, script = nil)
      @amount = output_amount
      @script_length = 0
      @script = nil
      self.set_script(script) if script
    end

    # attach PubKeyScript to TxOutput.
    # overwrites if exist.
    def script=(script)
      @script = script
      @script_length = script.to_json.length
    end
    alias_method :set_script, :script=

    def to_hash
      {
          amount: @amount,
          script_length: @script_length,
          script: @script.to_hash
      }
    end

    def to_json
      self.to_hash.to_json
    end
  end
end
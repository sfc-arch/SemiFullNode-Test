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
  class TransactionInput
    def initialize(prev_hash, prev_index, script = nil)
      @previous_hash = prev_hash
      @previous_index = prev_index
      @script_length = 0
      @script = nil
      @end_of_sequence = 0xffffffff

      self.set_script(script) if script
    end

    def script=(script)
      @script = script
      @script_length = script.to_json.length
    end
    alias_method :set_script, :script=

    def to_hash
      {
          prev_hash: @previous_hash,
          prev_index: @previous_index,
          script_length: @script_length,
          script: @script.to_hash
      }
    end

    def to_json
      self.to_hash.to_json
    end
  end
end
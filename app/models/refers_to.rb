# Transaction - Transaction
class RefersTo
  include Neo4j::ActiveRel

  from_class :Transaction
  to_class   :Transaction
  type 'referring'

  # {
  #     "prev_hash": "00000000000",
  #     "prev_index": 0,
  #     "script_length": 230,
  #     "script": {
  #         "signature": "7c33a427e67ba3d4faead818975ee4511cafc6d657bc8e0b4084f16f5778bcf2066e7dc34fa24dc520738c064891e270c557fe8eeccc731345104e347a431476",
  #         "public_key": "\u0003878cade4c9215ade91336e895a6e20343056bc5610039469b4dac1e2c708c2de"
  #     }
  # }

  property :index, type: Integer, null: false
  property :signature, type: String, default: nil
  property :public_key, type: String, default: nil

  # 保存する前にチェックするからいらないのでは？
  # property :valid, type: Boolean, null: false, default: false

  before_update :raise_if_locked

  validate # TODO: 自分のUTXOなのかの検証が必要！

  # Returns amount of the original payment to wallet.
  def amount
    payments = self.to_node.pay_tos.each_rel.select {|r| r.index == self.index}
    raise 'There are several payments with same indexes!!' unless payments.length == 1
    payment = payments.first
    return payment.amount
  end

  def to_hash
    if self.signature? and self.public_key?
      script = {
          signature: self.signature,
          public_key: self.public_key
      }

      {
          prev_hash: self.to_node.hash_value,
          prev_index: self.index,
          script_length: script.to_json.length,
          script: script
      }
    else
      {
          prev_hash: self.to_node.hash_value,
          prev_index: self.index
      }
    end
  end

  private

  def raise_if_locked
    if self.signature? && !self.signature_was.nil?
      raise "cannot edit locked reference."
    end
  end
end

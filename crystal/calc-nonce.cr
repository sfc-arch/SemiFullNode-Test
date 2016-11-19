require "socket"
require "big_int"
require "./openssl/src/openssl"


module SimpleProofOfWork
  MAX_NONCE = BigInt.new(2) ** 32

  def self.proof_of_work(header, difficulty_bits)
    # calculate difficulty target
    target = BigInt.new(2) ** (256 - difficulty_bits)

    # work until result is lower than target
    MAX_NONCE.times do |nonce|
      digester = OpenSSL::Digest::SHA256.new
      digester << (header.to_s + nonce.to_s)
      hash_result = digester.hexdigest.to_s

      # Check work
      if BigInt.new(hash_result, 16) < target
        # puts "Success with nonce #{nonce}"
        # puts "Hash is #{hash_result}"
        return hash_result, nonce
      end
    end

    # if failed
    raise "Failed after #{MAX_NONCE} tries..."
  end
end

string = ARGV[0]
difficulty_bits = ARGV[1].to_i
begin
  arr = SimpleProofOfWork.proof_of_work(string, difficulty_bits)
  print "#{arr[0]}\n#{arr[1]}"
rescue e
  p e
end
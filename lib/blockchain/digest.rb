require 'digest'

module Blockchain
  module Digest
    # SHA256 -> RIPEMD160
    def hash160(target)
      ::Digest::RMD160.hexdigest ::Digest::SHA256.hexdigest target
    end

    def sha256d(target)
      ::Digest::SHA256.hexdigest ::Digest::SHA256.hexdigest target
    end

    def sha256(target)
      ::Digest::SHA256.digest(target)
    end

    module_function :hash160, :sha256d, :sha256
  end
end

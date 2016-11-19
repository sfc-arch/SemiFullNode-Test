# == Schema Information
#
# Table name: block_infos
#
#  id               :integer          not null, primary key
#  merkle_root_hash :string
#  height           :integer
#  looked_up_rate   :float
#  deletable        :boolean
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

require 'rails_helper'

RSpec.describe BlockInfo, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end

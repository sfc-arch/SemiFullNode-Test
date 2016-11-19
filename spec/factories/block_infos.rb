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

FactoryGirl.define do
  factory :block_infos do
    merkle_root_hash "MyString"
    height 1
    looked_up_rate 1.5
    deletable false
  end
end

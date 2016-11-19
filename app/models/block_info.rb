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

class BlockInfo < ApplicationRecord
  include RenderSync::Actions
  RenderSync::Model.enable!

  sync :all

  # belongs_to :user
  # belongs_to :project

  # sync_scope :active, -> { where(completed: false) }
  # sync_scope :completed, -> { where(completed: true) }

  # after_save :sync_to_view
  after_create_commit do
    begin
      UpdateBroadcastJob.perform_later self
    rescue => e
      puts e
      puts e.backtrace
    end
  end
  # after_save do
  #   sync_update self #[self, self.project.reload]
  # end
  # after_destroy do
  #   sync_destroy self
  #   # sync_update self.project.reload
  # end
  #
  #
  # private
  # def sync_to_view
  #   p "sync"
  #   sync_update BlockInfo.all
  # end
end

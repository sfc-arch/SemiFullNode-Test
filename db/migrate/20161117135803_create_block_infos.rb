class CreateBlockInfos < ActiveRecord::Migration[5.0]
  def change
    create_table :block_infos do |t|
      t.string :merkle_root_hash
      t.integer :height
      t.float :looked_up_rate
      t.boolean :deletable

      t.timestamps
    end
  end
end

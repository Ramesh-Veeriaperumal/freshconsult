class AddBotTypeToBotFeedbacks < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :bot_feedbacks, atomic_switch: true do |m|
      m.add_column :bot_type, 'varchar(50) DEFAULT NULL'
      m.add_index [:account_id, :bot_id, :bot_type], name: 'index_bot_feedbacks_on_account_id_bot_id_bot_type'
    end
  end

  def self.down
    Lhm.change_table :bot_feedbacks, atomic_switch: true do |m|
      m.remove_column :bot_type
      m.remove_index [:account_id, :bot_id, :bot_type], name: 'index_bot_feedbacks_on_account_id_bot_id_bot_type'
    end
  end
end

class AddIndexToChatWidgets < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :chat_widgets, :atomic_switch => true do |m|
        m.add_index [:account_id, :widget_id], 'account_id_and_widget_id'
    end
  end

  def self.down
    Lhm.change_table :chat_widgets, :atomic_switch => true do |m|
        m.remove_index [:account_id, :widget_id], 'account_id_and_widget_id'
    end
  end
end
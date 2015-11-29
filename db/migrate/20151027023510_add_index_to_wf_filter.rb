class AddIndexToWfFilter < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :wf_filters, :atomic_switch => true do |m|
      m.add_index [:account_id, :type], "index_wf_filters_on_acc_id_and_type"
    end
  end

  def down
    Lhm.change_table :wf_filters, :atomic_switch => true do |m|
      m.remove_index [:account_id, :type], "index_wf_filters_on_acc_id_and_type"
    end
  end
end

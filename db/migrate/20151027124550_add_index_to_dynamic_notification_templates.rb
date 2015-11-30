class AddIndexToDynamicNotificationTemplates < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :dynamic_notification_templates, :atomic_switch => true do |m|
      m.add_index [:account_id, :email_notification_id, :category], "index_dynamic_notn_on_acc_and_notification_id_and_category"
    end
  end

  def down
    Lhm.change_table :dynamic_notification_templates, :atomic_switch => true do |m|
      m.remove_index [:account_id, :email_notification_id, :category], "index_dynamic_notn_on_acc_and_notification_id_and_category"
    end
  end
end

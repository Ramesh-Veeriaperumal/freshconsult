class AddRememberableAssociation < ActiveRecord::Migration
  shard :all

  def up
    Lhm.change_table :helpdesk_reminders, atomic_switch: true do |m|
      m.add_column :contact_id, 'bigint(20) unsigned DEFAULT NULL'
      m.add_column :company_id, 'bigint(20) unsigned DEFAULT NULL'
      m.add_column :reminder_at, :datetime
      m.add_index ['account_id', 'contact_id'], 
        'index_helpdesk_reminders_on_account_id_contact_id'
      m.add_index ['account_id', 'company_id'], 
        'index_helpdesk_reminders_on_account_id_company_id'
    end
  end

  def down
    Lhm.change_table :helpdesk_reminders, atomic_switch: true do |m|
      m.remove_index ['account_id', 'contact_id'], 
        'index_helpdesk_reminders_on_account_id_contact_id'
      m.remove_index ['account_id', 'company_id'], 
        'index_helpdesk_reminders_on_account_id_company_id'
      m.remove_column :company_id
      m.remove_column :contact_id
      m.remove_column :reminder_at
    end
  end
end
class AddMissingIndexToShard < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :users, :atomic_switch => true do |m|
        m.add_index :email, 'index_users_on_email'
    end

    Lhm.change_table :admin_user_accesses, :atomic_switch => true do |m|
        m.add_index [:account_id, :accessible_id, :accessible_type], 'index_admin_acc_id_type'
    end

    Lhm.change_table :google_contacts, :atomic_switch => true do |m|
        m.add_index [:account_id, :user_id], 'index_google_contacts_on_accid_and_uid'
    end

    Lhm.change_table :helpdesk_shared_attachments, :atomic_switch => true do |m|
        m.add_index [:account_id, :shared_attachable_id], 'index_helpdesk_attachement_shared_id_share_id'
    end

    Lhm.change_table :helpdesk_time_sheets, :atomic_switch => true do |m|
        m.add_index [:account_id, :workable_id, :workable_type], 'index_helpdesk_sheets_on_workable_acc'
    end

    Lhm.change_table :support_scores, :atomic_switch => true do |m|
        m.add_index [:account_id, :user_id, :created_at], 'index_support_scores_on_accid_and_uid_and_created_at'
        m.add_index [:account_id, :group_id, :created_at], 'index_support_scores_on_accid_and_gid_and_created_at'
        m.add_index [:account_id, :scorable_id, :scorable_type], 'index_support_scores_on_accid_scorable_id_scorable_type'
    end

  end

  def self.down
    Lhm.change_table :users, :atomic_switch => true do |m|
        m.remove_index :email, 'index_users_on_email'
    end

    Lhm.change_table :admin_user_accesses, :atomic_switch => true do |m|
        m.remove_index [:account_id, :accessible_id, :accessible_type], 'index_admin_acc_id_type'
    end

    Lhm.change_table :google_contacts, :atomic_switch => true do |m|
        m.remove_index [:account_id, :user_id], 'index_google_contacts_on_accid_and_uid'
    end

    Lhm.change_table :helpdesk_shared_attachments, :atomic_switch => true do |m|
        m.remove_index [:account_id, :shared_attachable_id], 'index_helpdesk_attachement_shared_id_share_id'
    end

    Lhm.change_table :helpdesk_timesheets, :atomic_switch => true do |m|
        m.remove_index [:account_id, :workable_id, :workable_type], 'index_helpdesk_sheets_on_workable_acc'
    end

    Lhm.change_table :support_scores, :atomic_switch => true do |m|
        m.remove_index [:account_id, :user_id, :created_at], 'index_support_scores_on_accid_and_uid_and_created_at'
        m.remove_index [:account_id, :group_id, :created_at], 'index_support_scores_on_accid_and_gid_and_created_at'
        m.remove_index [:account_id, :scorable_id, :scorable_type], 'index_support_scores_on_accid_scorable_id_scorable_type'
    end

  end
end

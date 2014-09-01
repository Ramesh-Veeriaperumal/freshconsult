class AddAccountIdIndexToAlmostAll < ActiveRecord::Migration
  def self.up
    add_index :business_calendars, :account_id
    add_index :customers, [:account_id, :name], :name => 'index_customers_on_account_id_and_name', :unique => true
    add_index :email_configs, [:account_id, :to_email], 
                    :name => 'index_email_configs_on_account_id_and_to_email', :unique => true
    add_index :email_notifications, [:account_id, :notification_type], 
                    :name => 'index_email_notifications_on_notification_type', :unique => true
    add_index :forum_categories, [:account_id, :name], 
                    :name => 'index_forum_categories_on_account_id_and_name', :unique => true
    add_index :forums, [:forum_category_id, :name], 
                    :name => 'index_forums_on_forum_category_id', :unique => true
    add_index :groups, [:account_id, :name], 
                    :name => 'index_groups_on_account_id', :unique => true
    add_index :helpdesk_activities, [:account_id, :notable_type, :notable_id], 
                    :name => 'index_helpdesk_activities_on_notables'
    add_index :helpdesk_form_customizers, :account_id, 
                    :name => 'index_helpdesk_form_customizers_on_account_id', :unique => true
    add_index :helpdesk_notes, [:account_id, :notable_type, :notable_id], 
                    :name => 'index_helpdesk_notes_on_notables'
    add_index :helpdesk_sla_policies, [:account_id, :name], 
                    :name => 'index_helpdesk_sla_policies_on_account_id_and_name', :unique => true
    add_index :helpdesk_tags, [:account_id, :name], 
                    :name => 'index_helpdesk_tags_on_account_id_and_name', :unique => true
    
    remove_index :helpdesk_tickets, :requester_id
    remove_index :helpdesk_tickets, :responder_id
    add_index :helpdesk_tickets, [:account_id, :requester_id], 
                    :name => 'index_helpdesk_tickets_on_account_id_and_requester_id'
    add_index :helpdesk_tickets, [:account_id, :responder_id], 
                    :name => 'index_helpdesk_tickets_on_account_id_and_responder_id'
    add_index :solution_articles, [:account_id, :folder_id], 
                    :name => 'index_solution_articles_on_account_id'
    add_index :solution_articles, :folder_id, 
                    :name => 'index_solution_articles_on_folder_id'
    add_index :solution_categories, [:account_id, :name], 
                    :name => 'index_solution_categories_on_account_id_and_name', :unique => true
    add_index :solution_folders, [:category_id, :name], 
                    :name => 'index_solution_folders_on_category_id_and_name', :unique => true
    add_index :users, [:account_id, :email], 
                    :name => 'index_users_on_account_id_and_email', :unique => true
    add_index :va_rules, [:account_id, :rule_type], 
                    :name => 'index_va_rules_on_account_id_and_rule_type'
  end

  def self.down    
    remove_index :va_rules, [:account_id, :rule_type]
    remove_index :users, [:account_id, :email]
    remove_index :solution_folders, [:category_id, :name]
    remove_index :solution_categories, [:account_id, :name]
    remove_index :solution_articles, :folder_id
    remove_index :solution_articles, [:account_id, :folder_id]
    remove_index :helpdesk_tickets, [:account_id, :responder_id]
    remove_index :helpdesk_tickets, [:account_id, :requester_id]
    add_index :helpdesk_tickets, :responder_id, :name => "index_helpdesk_tickets_on_responder_id"
    add_index :helpdesk_tickets, :requester_id, :name => "index_helpdesk_tickets_on_requester_id"
    remove_index :helpdesk_tags, [:account_id, :name]
    remove_index :helpdesk_sla_policies, [:account_id, :name]
    remove_index :helpdesk_notes, [:account_id, :notable_type, :notable_id]
    remove_index :helpdesk_form_customizers, :account_id
    remove_index :helpdesk_activities, [:account_id, :notable_type, :notable_id]
    remove_index :groups, [:account_id, :name]
    remove_index :forums, [:forum_category_id, :name]
    remove_index :forum_categories, [:account_id, :name]
    remove_index :email_notifications, [:account_id, :notification_type]
    remove_index :email_configs, [:account_id, :to_email]
    remove_index :customers, [:account_id, :name]
    remove_index :business_calendars, :account_id
  end
end

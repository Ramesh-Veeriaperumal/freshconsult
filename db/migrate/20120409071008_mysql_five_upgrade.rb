class MysqlFiveUpgrade < ActiveRecord::Migration
  def self.up
    execute("alter table helpdesk_tickets add index `helpdesk_tickets_id` (`id`),
            drop primary key,
            drop index index_helpdesk_tickets_on_account_id_and_requester_id,
            drop index index_helpdesk_tickets_on_account_id_and_responder_id,
            drop index index_helpdesk_tickets_on_requester_id,
            add key index_helpdesk_tickets_on_account_id_and_created_at_and_id(account_id, created_at, id),
            add key index_helpdesk_tickets_on_account_id_and_updated_at_and_id(account_id, updated_at, id),
            add key index_helpdesk_tickets_on_account_id_and_due_by_and_id(account_id, due_by, id),
            add key index_helpdesk_tickets_on_requester_id_and_account_id(requester_id,account_id),
            add key index_helpdesk_tickets_on_responder_id_and_account_id (responder_id,account_id)
            PARTITION BY HASH(account_id) PARTITIONS 128")
            
   execute("alter table helpdesk_notes add index `helpdesk_notes_id` (`id`), 
            drop primary key,
            drop index index_helpdesk_notes_on_notable_id,
            drop index index_helpdesk_notes_on_notable_type
            PARTITION BY HASH(account_id) PARTITIONS 128")
   
   
   execute("alter table helpdesk_activities add index `helpdesk_activities_id` (`id`),
            drop primary key,
            drop index helpdesk_activities_notable_type_and_id
            PARTITION BY HASH(account_id) PARTITIONS 128")
   
   execute("alter table helpdesk_attachments add index `helpdesk_attachments_id` (`id`),
            drop primary key,
            drop index index_helpdesk_attachments_on_attachable_id,
            add index `index_helpdesk_attachments_on_attachable_id` (`account_id`,`attachable_id`,`attachable_type`(14))
            PARTITION BY HASH(account_id) PARTITIONS 128")
   
   execute("alter table flexifields add index `flexifields_id` (`id`),
            drop primary key,
            drop index idx_ff_poly,
            add index `index_flexifields_on_flexifield_def_id_and_flexifield_set_id` (`account_id`,`flexifield_set_id`)
            PARTITION BY HASH(account_id) PARTITIONS 128")
            
   execute("alter table users add index `users_id` (`id`),
            drop  primary KEY,
            drop index index_users_on_single_access_token,
            drop index index_users_on_account_id,
            drop index index_users_on_customer_id,
            drop index index_users_on_email,
            drop index index_users_on_perishable_token,
            drop index index_users_on_persistence_token,
            add key index_users_on_customer_id_and_account_id(customer_id,account_id), 
            add key index_users_on_perishable_token_and_account_id(perishable_token,account_id), 
            add key index_users_on_persistence_token_and_account_id (persistence_token,account_id), 
            add UNIQUE index index_users_on_account_id_and_single_access_token(single_access_token ,account_id)
            PARTITION BY HASH(account_id) PARTITIONS 128")     
            
    execute("alter table helpdesk_ticket_states add index `helpdesk_ticket_states_id` (`id`), 
            drop primary key,
            PARTITION BY HASH(account_id) PARTITIONS 128")
   
  end
  def self.down
  end
end

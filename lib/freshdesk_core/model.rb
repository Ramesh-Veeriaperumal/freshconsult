module FreshdeskCore::Model
  include Subscription::Events::Constants

  HELPKIT_TABLES =  [   "account_additional_settings",  
                        "account_configurations", 
                        "addresses",                    
                        "admin_canned_responses", 
                        "admin_data_imports",           
                        "authorizations", 
                        "business_calendars",           
                        "ca_folders", 
                        "conversion_metrics",           
                        "data_exports", 
                        "day_pass_configs",              
                        "day_pass_usages", 
                        "day_pass_usages",              
                        "email_configs", 
                        "email_notification_agents",    
                        "email_notifications", 
                        "es_enabled_accounts",          
                        "features", 

                        "forums",
                          "customer_forums",
                          "forum_categories", 

                        "groups", 
                          "agent_groups",
                        
                        "helpdesk_activities", 
                        "helpdesk_dropboxes",
                        "helpdesk_picklist_values", 
                        "helpdesk_reminders",
                        "helpdesk_subscriptions",

                        "helpdesk_notes",
                          "helpdesk_note_bodies",
                          "helpdesk_schema_less_notes",
                          "helpdesk_external_notes", 
                        
                        "helpdesk_tickets",
                          "helpdesk_ticket_bodies",
                          "helpdesk_ticket_states",
                          "helpdesk_ticket_statuses",
                          "helpdesk_schema_less_tickets",
                          "helpdesk_time_sheets",
                          "flexifields",
                            "flexifield_defs", 
                            "flexifield_def_entries",
                          
                        "helpdesk_tags",
                          "helpdesk_tag_uses",
                           
                        "installed_applications", 
                          "integrated_resources", 
                          "integrations_user_credentials", 
                          "key_value_pairs", 
                          "google_accounts", 
                          "google_contacts", 

                        "monitorships", 

                        "posts", 
                        "products",

                        "quests",
                          "achieved_quests",

                        "roles",
                        "user_roles",

                        "scoreboard_levels",
                        "scoreboard_ratings",
                        "support_scores",

                        "sla_policies", 
                          "sla_details", 

                        "social_facebook_pages", 
                          "social_fb_posts", 

                        "social_twitter_handles",
                          "social_tweets", 

                        "solution_categories", 
                          "solution_customer_folders", 
                          "solution_folders",
                         
                        "subscriptions",

                        "surveys",
                          "survey_handles",
                          "survey_results", 
                          "survey_remarks", 
                        
                        "topics",
                          "ticket_topics",
                        
                        "users",
                          "admin_user_accesses",
                          "agents", 
                          "customers", 
                        
                        "votes", 
                        "va_rules", 
                        "wf_filters" 
                    ]

  STATUS = {
      :deleted => 0,
      :scheduled => 1,
      :in_progress => 2,
      :failed => 3
    }            

  def perform_destroy(account)
    add_churn(account) unless account.subscription_payments.blank?
    delete_jira_webhooks(account)
    clear_attachments(account)
    
    delete_data_from_tables(account.id)
    account.destroy
  end

  private

    def add_churn(account)
      subscription = account.subscription
      event = subscription_info(subscription).merge(deleted_event_info(subscription))

      SubscriptionEvent.create(event)
    end

    def subscription_info(subscription)
      SUBCRIPTION_INFO.inject({}) { |h, (k, v)| h[k] = subscription.send(v); h }
    end

    def deleted_event_info(subscription)
      {
        :account_id => subscription.account_id,
        :code => CODES[:deleted],
        :cmrr => (subscription.amount/subscription.renewal_period)
      }
    end


    def jira_enabled?(account)
      app_id = Integrations::Application.find_by_name('jira').id
      account.installed_applications.find_by_application_id(app_id)
    end

    def delete_jira_webhooks(account)
      if(app = jira_enabled?(account))
        Integrations::JiraWebhook.new(app, HttpRequestProxy.new).send_later(:delete_webhooks)
      end
    end


    def clear_attachments(account)
      delete_files(account)
      delete_info_from_table(account.id)
    end

    def delete_files(account)
      account.attachments.find_in_batches do |attachments|
        attachments.each do |attachment|
          prefix = "data/helpdesk/attachments/#{Rails.env}/#{attachment.id}/"
          objects = AWS::S3::Bucket.objects(S3_CONFIG[:bucket], :prefix => prefix)
          
          objects.each do |object| 
            object.delete if object.key.include?(attachment.content_file_name)
          end
        end
      end
    end

    def delete_info_from_table(account_id)
      delete_query = "DELETE FROM helpdesk_attachments WHERE account_id = #{account_id}" 
      execute_sql(delete_query) unless account_id.blank?
    end


    def delete_data_from_tables(account_id)
      HELPKIT_TABLES.each { |table| execute_sql(delete_query(table, account_id)) } unless account_id.blank?
    end
           
    def delete_query(table_name, account_id)
      "DELETE FROM #{table_name} WHERE account_id = #{account_id}"
    end 

    def execute_sql(delete_query)
      ActiveRecord::Base.connection.execute(delete_query)
    end
    
end
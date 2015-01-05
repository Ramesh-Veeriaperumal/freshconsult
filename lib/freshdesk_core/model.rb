module FreshdeskCore::Model
  include Subscription::Events::Constants
  include Redis::RedisKeys
  include Redis::OthersRedis	

  HELPKIT_TABLES =  [   "account_additional_settings",  
                        "account_configurations", 
                        "addresses",                    
                        "admin_canned_responses", 
                        "admin_data_imports",
                        "article_tickets",
                        "authorizations", 
                        "business_calendars",           
                        "ca_folders", 
                        "company_forms",
                        "company_fields",
                        "company_field_choices",
                        "company_field_data",
                        "conversion_metrics",           
                        "contact_forms",
                        "contact_fields",
                        "contact_field_choices",
                        "contact_field_data",
                        "data_exports", 
                        "day_pass_configs",              
                        "day_pass_usages", 
                        "day_pass_usages",              
                        "email_configs", 
                        "email_notification_agents",    
                        "email_notifications", 
                        "dynamic_notification_templates",
                        "features", 

                        "forums",
                          "customer_forums",
                          "forum_categories",
                          "forum_moderators",

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
                        
                        "social_streams",
                          "social_ticket_rules",
                        
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
                          "user_emails",
                          "agents", 
                          "customers",
                        
                        "votes", 
                        "va_rules", 
                        "wf_filters",
                        "report_filters",
                        "whitelisted_ips",
                        "helpdesk_ticket_fields",
                        "helpdesk_nested_ticket_fields", 
                        "helpdesk_shared_attachments",
                        
                        "helpdesk_accesses",
                          "user_accesses",
                          "group_accesses",

                        "mobihelp_apps", 
                        "mobihelp_devices",
                        "mobihelp_ticket_infos"
                    ]

  STATUS = {
      :deleted => 0,
      :scheduled => 1,
      :in_progress => 2,
      :failed => 3
    }            

  def perform_destroy(account)
    delete_gnip_twitter_rules(account)
    delete_social_redis_keys(account)
    delete_facebook_subscription(account)
    delete_jira_webhooks(account)
    clear_attachments(account)
    remove_mobile_registrations(account.id)
    remove_addon_mapping(account)
    remove_card_info(account)
    $redis_others.srem(USER_EMAIL_MIGRATED, account.id) #for contact merge delta
    
    delete_data_from_tables(account.id)
    account.destroy
  end

  private

    def remove_mobile_registrations account_id
        message = {
            :account_id => account_id,
			:delete_axn => :account
        }.to_json
        publish_to_channel MOBILE_NOTIFICATION_REGISTRATION_CHANNEL, message
    end
  
    def delete_gnip_twitter_rules(account)
      account.twitter_handles.each do |twt_handle|
        streams = twt_handle.twitter_streams
        default_stream = streams.select {|stream| stream.default_stream? }.first
        if default_stream
          args = default_stream.construct_unsubscribe_args(nil)
          Social::Workers::Gnip::TwitterRule.perform(args)
        end
      end
    end
    
    def delete_social_redis_keys(account)
      account.twitter_streams.each do |stream|
        stream.clear_volume_in_redis
      end
      account.agents.each do |agent|
        agent.clear_social_searches
      end
    end

    def delete_facebook_subscription(account)
      account.facebook_pages.each do |fb_page|
        fb_page.cleanup
      end
    end
    
    def jira_enabled?(account)
      app_id = Integrations::Application.find_by_name('jira').id
      account.installed_applications.find_by_application_id(app_id)
    end

    def delete_jira_webhooks(account)
      if(app = jira_enabled?(account))
        args = {
          :username => app.configs_username,
          :password => app.configs_password,
          :domain => app.configs_domain,
          :operation => "delete_webhooks",
          :app_id => app.id
      }
        Resque.enqueue(Workers::Integrations::JiraAccountUpdates, args)
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
          objects = AwsWrapper::S3Object.find_with_prefix(S3_CONFIG[:bucket],prefix)
          
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

    def remove_card_info(account)
      if account.subscription.card_number.present?
        Billing::Subscription.new.remove_credit_card(account.id)
      end
    end

    def remove_addon_mapping(account)
      Subscription::AddonMapping.destroy_all(:account_id => account.id)
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

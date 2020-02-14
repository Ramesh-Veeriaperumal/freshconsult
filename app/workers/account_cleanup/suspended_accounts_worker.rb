module AccountCleanup
  class SuspendedAccountsWorker < BaseWorker

    include FreshdeskCore::Model
    include MemcacheKeys
    include AccountCleanup::Common

    sidekiq_options :queue => :suspended_accounts_deletion, :retry => 0, :failures => :exhausted

    
    NON_PARTITION_TABLES =["account_additional_settings", "account_configurations", "achieved_quests", "addresses", "admin_canned_responses", "admin_data_imports", "admin_user_accesses", "agent_groups", "agents", "applications", "article_tickets", "authorizations", "business_calendars", "ca_folders", "chat_settings", "chat_widgets", "company_domains", "company_field_choices", "company_field_data", "company_fields", "company_forms", "contact_field_choices", "contact_field_data", "contact_fields", "contact_forms", "conversion_metrics", "customer_forums", "customers", "data_exports", "day_pass_configs", "day_pass_purchases", "day_pass_usages", "deleted_customers", "dynamic_notification_templates", "ebay_questions", "ecommerce_accounts", "email_configs", "email_notification_agents", "email_notifications", "es_enabled_accounts", "flexifield_def_entries", "flexifield_defs", "form_ticket_field_values", "forum_categories", "forum_moderators", "forums", "freshfone_accounts", "freshfone_blacklist_numbers", "freshfone_call_metrics", "freshfone_callers", "freshfone_calls_meta", "freshfone_credits", "freshfone_ivrs", "freshfone_number_addresses", "freshfone_number_groups", "freshfone_numbers", "freshfone_other_charges", "freshfone_payments", "freshfone_supervisor_controls", "freshfone_usage_triggers", "freshfone_users", "freshfone_whitelist_countries", "google_accounts", "google_contacts", "groups", "helpdesk_accesses", "helpdesk_nested_ticket_fields", "helpdesk_picklist_values", "helpdesk_reminders", "helpdesk_section_fields", "helpdesk_sections", "helpdesk_shared_attachments", "helpdesk_subscriptions", "helpdesk_ticket_fields", "helpdesk_ticket_statuses", "helpdesk_time_sheets", "imap_mailboxes", "installed_applications", "integrated_resources", "integrations_user_credentials", "mobihelp_app_solutions", "mobihelp_apps", "mobihelp_devices", "mobihelp_ticket_infos", "monitorships", "oauth_access_grants", "oauth_access_tokens", "oauth_applications", "password_policies", "portal_forum_categories", "portal_pages", "portal_solution_categories", "portal_templates", "portals", "posts", "products", "quests", "report_filters", "roles", "scoreboard_levels", "scoreboard_ratings", "section_picklist_value_mappings", "sla_details", "sla_policies", "smtp_mailboxes", "social_facebook_pages", "social_fb_posts", "social_streams", "social_ticket_rules", "social_tweets", "social_twitter_handles", "solution_article_bodies", "solution_article_meta", "solution_articles", "solution_categories", "solution_category_meta", "solution_customer_folders", "solution_draft_bodies", "solution_drafts", "solution_folder_meta", "solution_folders", "sub_section_fields", "subscription_events", "subscription_invoices", "subscription_payments", "subscriptions", "survey_question_choices", "survey_questions", "surveys", "ticket_form_fields", "ticket_topics", "topics", "user_companies", "va_rules", "votes", "wf_filters", "ebay_questions", "app_business_rules", "features", "freshfone_caller_ids", "freshfone_subscriptions","helpdesk_permissible_domains", "outgoing_email_domain_categories", "remote_integrations_mappings", "schedule_configurations", "scheduled_tasks", "whitelist_users", "whitelisted_ips"]

    #helpdesk_attachmnets not included here

    PARTITION_TABLES = ["helpdesk_tickets","helpdesk_notes","users","helpdesk_ticket_states","flexifields","helpdesk_activities","survey_remarks",
                        "survey_handles","survey_results","survey_result_data","helpdesk_schema_less_tickets", "helpdesk_schema_less_notes","support_scores","helpdesk_dropboxes","helpdesk_external_notes",
                        "helpdesk_ticket_bodies","helpdesk_note_bodies","user_emails","freshfone_calls","archive_tickets","archive_notes","archive_ticket_associations","archive_note_associations","archive_childs"]

    UNINDEXED_TABLES = { 
      :helpdesk_tags => [ :helpdesk_tag_uses, :tag_id ] # related table, indexed id
    }

    TABLES = PARTITION_TABLES + NON_PARTITION_TABLES 

    def perform(args)
      begin
        Account.reset_current_account
        select_in_account(args["shard_name"],args["account_id"])
      rescue Exception => e
          puts e
          NewRelic::Agent.notice_error(e, :description => "Unable to perform suspended account deletion for Shard: #{args["shard_name"]} and Account: #{args["account_id"]}")
      ensure
        Account.reset_current_account
      end

    end

    def delete_in_batches(account_id,ids,table)
      delete_query = "delete from #{table} where id in (#{ids.join(',')}) and account_id = #{account_id}"
      ActiveRecord::Base.connection.execute(delete_query)
      puts delete_query
    end

    def select_in_account(shard_name,account_id)
      time_taken = Benchmark.ms do
        Sharding.run_on_shard(shard_name) do
          account = Account.find account_id
          account.make_current
          return unless account.subscription.suspended?
          UserNotifier.notify_account_deletion(build_notification_data) if Rails.env.production? #send email to infosec team
          perform_delete(account)
          clean_attachments(account_id: account_id)
          portal_urls = account.portals.map { |p| p.portal_url if p.portal_url.present? }
          TABLES.each do |table|
            while(true)
              query = ("select id from #{table} where account_id = #{account_id} limit 50")
              puts query
              ids = ActiveRecord::Base.connection.select_values(query)
              ids_size  = ids.size
              break if ids_size == 0
              delete_in_batches(account_id,ids,table) 
              break if ids_size <50
            end
          end
           handle_unindexed_tables(account_id, shard_name)
           clear_domain_cache(account, portal_urls)
           delete_query = "delete from accounts where id = #{account_id}" 
           ActiveRecord::Base.connection.execute(delete_query)  
        end
      end
      delete_shard_domain_mappings(shard_name, account_id)
      puts "******************** #{time_taken} ******************************************************************"
    end

    def delete_shard_domain_mappings(shard_name, account_id)
      # Deleting by active record to invoke callbacks for clearing cache
      # this will delete domain mapping also
       shard = ShardMapping.find_by_account_id(account_id)
       shard.destroy 
    end

    def build_notification_data
      shard_info = ShardMapping.find(Account.current.id)
      {
        :account_id       => Account.current.id,
        :name             => Account.current.name,
        :account_verified => !Account.current.reputation.zero?,
        :shard            => shard_info.shard_name,
        :pod_info         => shard_info.pod_info,
        :contact_info     => Account.current.contact_info,
        :created_at       => Account.current.created_at.to_s(:db)
      }
    end

    def clear_domain_cache(account, portal_urls)
      key = ACCOUNT_BY_FULL_DOMAIN % { :full_domain => account.full_domain }
      MemcacheKeys.delete_from_cache key

      portal_urls.each do |p_url|
        key = PORTAL_BY_URL % { :portal_url => p_url }
        MemcacheKeys.delete_from_cache key
      end
    end

    def handle_unindexed_tables(account_id, shard_name)
      UNINDEXED_TABLES.each do |table_name, related_table_info|
        query = "select id from #{table_name} where account_id = #{account_id}"
        ids = ActiveRecord::Base.connection.select_values(query)
        break if ids.size == 0
        delete_in_batches(account_id, ids, table_name)
        related_table, related_id = related_table_info
        query = "select id from #{related_table} where #{related_id} in (#{ids.join(',')})"
        related_ids = ActiveRecord::Base.connection.select_values(query)
        delete_in_batches(account_id, related_ids, related_table) if related_ids.size > 0
      end
    end

    def perform_delete(account)
      # SearchSidekiq::RemoveFromIndex::AllDocuments.perform_async if Account.current.esv1_enabled?
      delete_gnip_twitter_rules(account)
      delete_social_redis_keys(account)
      delete_facebook_subscription(account)
      delete_jira_webhooks(account)
      remove_mobile_registrations(account.id)
      remove_addon_mapping(account)
      remove_card_info(account)
    end

  end
end

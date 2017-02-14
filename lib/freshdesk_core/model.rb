module FreshdeskCore::Model
  include Subscription::Events::Constants
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Cache::Memcache::WhitelistUser
  include Redis::PortalRedis

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
                        "email_configs",
                        "dkim_category_change_activities",
                        "email_notification_agents",
                        "email_notifications",
                        "dynamic_notification_templates",
                        "features",

                        "forums",
                          "customer_forums",
                          "forum_categories",
                          "portal_forum_categories",
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
                          "helpdesk_broadcast_messages",

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
                        "portals",
                          "portal_pages",
                          "portal_templates",

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
                          "portal_solution_categories",
                          "solution_articles",
                          "solution_drafts",
                          "solution_draft_bodies",
                          "solution_article_bodies",
                          "solution_category_meta",
                          "solution_folder_meta",
                          "solution_article_meta",

                        "subscriptions",
                        "subscription_invoices",

                        "surveys",
                          "survey_questions",
                          "survey_question_choices",
                          "survey_handles",
                          "survey_results",
                          "survey_result_data",
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
                        "mobihelp_ticket_infos",
                        "oauth_applications",
                        "oauth_access_grants",
                        "oauth_access_tokens",
                        "archive_tickets",
                        "archive_ticket_associations",
                        "archive_notes",
                        "archive_note_associations",
                        "archive_childs",
                        "password_policies",
                        "chat_widgets",
                        "chat_settings",
                        "freshfone_blacklist_numbers",
                        "freshfone_calls",
                        "freshfone_callers",
                        "freshfone_ivrs",
                        "freshfone_numbers",
                        "freshfone_usage_triggers",
                        "freshfone_users",
                        "freshfone_accounts",
                        "freshfone_number_addresses",
                        "freshfone_calls_meta",
                        "freshfone_credits",
                        "freshfone_number_groups",
                        "freshfone_other_charges",
                        "freshfone_payments",
                        "freshfone_whitelist_countries",
                        "freshfone_subscriptions",
                        "freshfone_supervisor_controls",
                        "freshfone_caller_ids",

                        "survey_questions",
                        "survey_question_choices",
                        "survey_result_data",
                        "day_pass_purchases",
                        "ecommerce_accounts",
                        "ebay_questions",
                        "form_ticket_field_values",
                        "helpdesk_sections",
                        "helpdesk_section_fields",
                        "section_picklist_value_mappings",
                        "imap_mailboxes",
                        "app_business_rules",
                        "mobihelp_app_solutions",
                        "smtp_mailboxes",
                        "ticket_form_fields",
                        "user_companies",
                        "company_domains",
                        "helpdesk_permissible_domains",
                        "outgoing_email_domain_categories",
                        "ticket_templates",
                        "cti_calls",
                        "cti_phones",
                        "status_groups",
                        "sync_accounts",
                        "sync_entity_mappings",
                        "parent_child_templates"
                    ]

  STATUS = {
      :deleted => 0,
      :scheduled => 1,
      :in_progress => 2,
      :failed => 3
    }

  def perform_destroy(account)
    delete_gnip_twitter_rules(account)
    delete_dkim_r53_entries(account)
    delete_social_redis_keys(account)
    delete_facebook_subscription(account)
    delete_jira_webhooks(account)
    delete_cloud_element_instances(account)
    clear_attachments(account)
    remove_mobile_registrations(account.id)
    remove_addon_mapping(account)
    remove_card_info(account)
    remove_whitelist_users(account.id)
    remove_remote_integration_mappings(account.id)
    remove_round_robin_redis_info(account)
    delete_sitemap(account)
    remove_from_spam_detection_service(account)
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
          Social::Gnip::RuleWorker.perform_async(args)
        end
      end
    end
    
    def delete_dkim_r53_entries(account)
      account.outgoing_email_domain_categories.dkim_configured_domains.each do |domain_category|
        domain_category.status = OutgoingEmailDomainCategory::STATUS['delete']
        domain_category.save
        Dkim::RemoveDkimConfig.new(domain_category).remove_records
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

    def cloud_elements_apps_enabled?(account)
      cloud_app_names = Integrations::CloudElements::Constant::APP_NAMES
      apps_query = ["applications.name=?"] * cloud_app_names.size
      apps_query = apps_query.join(" OR ")
      cloud_apps_id = Integrations::Application.where(apps_query, *cloud_app_names).map{|app| app}
      installed_apps_query = ["installed_applications.application_id = ?"] * cloud_apps_id.size
      installed_apps_query = installed_apps_query.join(" OR ")
      Integrations::InstalledApplication.where(installed_apps_query, *cloud_apps_id)
    end

    def delete_cloud_element_instances(account)
      if(installed_apps = cloud_elements_apps_enabled?(account))
        installed_apps.each do |installed_app|  
          app_name = installed_app.application.name
          formula_details = {
            :freshdesk => { :id => installed_app.configs_helpdesk_to_crm_formula_instance, :template_id => Integrations::HELPDESK_TO_CRM_FORMULA_ID[app_name]}, 
            :hubs => {:id => installed_app.configs_crm_to_helpdesk_formula_instance, :template_id => Integrations::CRM_TO_HELPDESK_FORMULA_ID[app_name]}
          }

          formula_details.keys.each do |key|
            metadata = {:formula_template_id => formula_details[key][:template_id], :id => formula_details[key][:id]}
            options = {:metadata => metadata, :app_id => installed_app.application_id, :object => Integrations::CloudElements::Constant::NOTATIONS[:formula]}
            Integrations::CloudElementsDeleteWorker.new.perform(options)  
          end

          [installed_app.configs_element_instance_id, installed_app.configs_fd_instance_id].each do |element_id|
            options = {:metadata => {:id => element_id}, :app_id => installed_app.application_id, :object => Integrations::CloudElements::Constant::NOTATIONS[:element]}
            Integrations::CloudElementsDeleteWorker.new.perform(options)     
          end 
        end
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

    def remove_whitelist_users(account_id)
      WhitelistUser.where(account_id: account_id).delete_all
      clear_whitelist_users_cache
    end

    def remove_remote_integration_mappings(account_id)
      RemoteIntegrationsMapping.where(account_id: account_id).delete_all
    end


    def delete_sitemap(account)
      key = SITEMAP_OUTDATED % { :account_id => account.id }
      remove_portal_redis_key(key)
      
      account.portals.each do |portal|
          portal.clear_sitemap_cache
      end

      path = "sitemap/#{account.id}/"
      objects = AwsWrapper::S3Object.find_with_prefix(S3_CONFIG[:bucket],path)
      objects.each do |object| 
        object.delete
      end
    end

    def remove_round_robin_redis_info(account)
      account.groups.find_each do |group|
        group.remove_round_robin_data(group.agents.pluck(:id))
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

    def remove_from_spam_detection_service(account)
      if account.launched?(:spam_detection_service)
        result = FdSpamDetectionService::Service.new(account.id).delete_tenant
        Rails.logger.info "Response for deleting tenant in SDS: #{result}"
        account.rollback(:spam_detection_service)
      end
    end
    
end

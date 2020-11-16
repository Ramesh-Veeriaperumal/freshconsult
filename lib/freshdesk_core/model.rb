module FreshdeskCore::Model
  include Subscription::Events::Constants
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Cache::Memcache::WhitelistUser
  include Redis::PortalRedis
  include Mysql::RecordsHelper
  include Utils::Freno
  APPLICATION_NAME = 'AccountCleanup::DeleteAccount'
  # These are tables without id column. account_id need not be mentioned in the composite key list.
  HELPKIT_TABLES_AND_COMPOSITE_KEYS = { :user_roles => ['user_id', 'role_id'], :user_accesses=> ['user_id', 'access_id'],
                                      :group_accesses => ['group_id', 'access_id'] }

  HELPKIT_TABLES = ['helpdesk_attachments',
                    'account_additional_settings',
                    'account_configurations',
                    'addresses',
                    'admin_canned_responses',
                    'admin_data_imports',
                    'article_tickets',
                    'authorizations',
                    'business_calendars',
                    'ca_folders',
                    'company_forms',
                    'company_fields',
                    'company_field_choices',
                    'company_field_data',
                    'company_filters',
                    'conversion_metrics',
                    'contact_forms',
                    'contact_fields',
                    'contact_field_choices',
                    'contact_field_data',
                    'contact_filters',
                    'data_exports',
                    'dashboards',
                    'dashboard_widgets',
                    'day_pass_configs',
                    'day_pass_usages',
                    'email_configs',
                    'dkim_category_change_activities',
                    'email_notification_agents',
                    'email_notifications',
                    'dynamic_notification_templates',
                    'scheduled_exports',

                    'forums',
                    'customer_forums',
                    'forum_categories',
                    'portal_forum_categories',
                    'forum_moderators',

                    'groups',
                    'agent_groups',

                    'helpdesk_activities',
                    'helpdesk_dropboxes',
                    'helpdesk_picklist_values',
                    'helpdesk_reminders',
                    'helpdesk_subscriptions',

                    'helpdesk_notes',
                    'helpdesk_note_bodies',
                    'helpdesk_schema_less_notes',
                    'helpdesk_external_notes',
                    'helpdesk_broadcast_messages',

                    'helpdesk_tickets',
                    'helpdesk_ticket_bodies',
                    'helpdesk_ticket_states',
                    'helpdesk_ticket_statuses',
                    'helpdesk_schema_less_tickets',
                    'helpdesk_time_sheets',
                    'flexifields',
                    'flexifield_defs',
                    'flexifield_def_entries',

                    'helpdesk_tags',
                    'helpdesk_tag_uses',

                    'installed_applications',
                    'integrated_resources',
                    'integrations_user_credentials',
                    'google_accounts',
                    'google_contacts',

                    'monitorships',

                    'posts',
                    'products',
                    'portals',
                    'portal_pages',
                    'portal_templates',

                    'quests',
                    'achieved_quests',

                    'roles',

                    'scoreboard_levels',
                    'scoreboard_ratings',
                    'support_scores',

                    'sla_policies',
                    'sla_details',

                    'social_facebook_pages',
                    'social_fb_posts',

                    'social_twitter_handles',
                    'social_tweets',

                    'social_streams',
                    'social_ticket_rules',

                    'solution_categories',
                    'solution_customer_folders',
                    'solution_folders',
                    'portal_solution_categories',
                    'solution_articles',
                    'solution_drafts',
                    'solution_draft_bodies',
                    'solution_article_bodies',
                    'solution_category_meta',
                    'solution_folder_meta',
                    'solution_article_meta',

                    'subscriptions',
                    'subscription_invoices',

                    'surveys',
                    'survey_questions',
                    'survey_question_choices',
                    'survey_handles',
                    'survey_results',
                    'survey_result_data',
                    'survey_remarks',

                    'topics',
                    'ticket_topics',

                    'users',
                    'admin_user_accesses',
                    'user_emails',
                    'agents',
                    'customers',

                    'votes',
                    'va_rules',
                    'wf_filters',
                    'report_filters',
                    'whitelisted_ips',
                    'helpdesk_ticket_fields',
                    'helpdesk_nested_ticket_fields',
                    'helpdesk_shared_attachments',

                    'helpdesk_accesses',

                    'mobihelp_apps',  
                    'mobihelp_devices', 
                    'mobihelp_ticket_infos',
                    'oauth_applications',
                    'oauth_access_grants',
                    'oauth_access_tokens',
                    'archive_tickets',
                    'archive_ticket_associations',
                    'archive_notes',
                    'archive_note_associations',
                    'archive_childs',
                    'password_policies',
                    'chat_widgets',
                    'chat_settings',
                    'freshcaller_accounts',
                    'freshcaller_agents',
                    'day_pass_purchases',
                    'ecommerce_accounts',
                    'ebay_questions',
                    'form_ticket_field_values',
                    'helpdesk_sections',
                    'helpdesk_section_fields',
                    'section_picklist_value_mappings',
                    'imap_mailboxes',
                    'app_business_rules',
                    'mobihelp_app_solutions',
                    'smtp_mailboxes',
                    'ticket_form_fields',
                    'user_companies',
                    'company_domains',
                    'helpdesk_permissible_domains',
                    'outgoing_email_domain_categories',
                    'ticket_templates',
                    'cti_calls',
                    'cti_phones',
                    'status_groups',
                    'sync_accounts',
                    'sync_entity_mappings',
                    'parent_child_templates',
                    'collab_settings',
                    'bots',
                    'freddy_bots',
                    'bot_tickets',
                    'canned_form_handles',
                    'contact_notes',
                    'contact_note_bodies',
                    'company_notes',
                    'company_note_bodies',
                    'skills',
                    'user_skills',
                    'admin_sandbox_jobs',
                    'help_widgets',
                    'help_widget_suggested_article_rules',
                    'help_widget_solution_categories',
                    'bot_responses',
                    'custom_translations',
                    'ticket_field_data',        
                    'admin_sandbox_accounts',
                    'agent_types',
                    'bot_feedback_mappings',
                    'bot_feedbacks',
                    'canned_forms',
                    'dashboard_announcements',
                    'deleted_customers',
                    'denormalized_flexifields',
                    'dkim_records',
                    'freshcaller_calls',
                    'freshchat_accounts',
                    'group_types',
                    'help_widget_solution_categories',
                    'helpdesk_approvals',
                    'helpdesk_approver_mappings',
                    'solution_article_versions',
                    'trial_subscriptions',
                    'scheduled_tasks',
                    'subscription_requests',
                    'qna_insights_reports',
                    'schedule_configurations',
                    'helpdesk_choices'].freeze

  STATUS = {
      :deleted => 0,
      :scheduled => 1,
      :in_progress => 2,
      :failed => 3
    }

  ARCHIVE_S3_BUCKET_MAPPING = {
    :archive_tickets => :archive_ticket_body,
    :archive_notes => :note_body
  }

  DELETE_BATCH_COUNT = 10

  def perform_destroy(account)
    @continue_account_destroy_from ||= 0
    @shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
    account_destroy_functions = [
      lambda { publish_account_destroy_to_central(account) },
      lambda { delete_gnip_twitter_rules(account) },
      lambda { delete_dkim_r53_entries(account) },
      lambda { delete_social_redis_keys(account) },
      lambda { delete_facebook_subscription(account) },
      lambda { delete_jira_webhooks(account) },
      lambda { delete_cloud_element_instances(account) },
      lambda { clear_attachments(account) },
      lambda { clear_archive_data_from_s3(account) },
      lambda { remove_mobile_registrations(account.id) },
      lambda { remove_addon_mapping(account) },
      lambda { remove_card_info(account) },
      lambda { remove_whitelist_users(account.id) },
      lambda { remove_remote_integration_mappings(account.id) },
      lambda { remove_round_robin_redis_info(account) },
      lambda { account.delete_sitemap },
      lambda { remove_from_spam_detection_service(account) },
      lambda { delete_canned_forms(account) },
      lambda { delete_widget_data_from_s3(account) },
      lambda { delete_account_from_fluffy(account) },
      lambda { delete_data_from_tables(account.id) },
      lambda { delete_data_from_tables_without_id(account.id) },
      lambda { account.destroy } ]

    account_destroy_functions.slice(@continue_account_destroy_from,
      account_destroy_functions.size).each_with_index do |function, index|
      begin
        function.call
      rescue ReplicationLagError => e
        @continue_account_destroy_from += index
        raise e
      end
    end
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
      account.outgoing_email_domain_categories.dkim_configured_domains.order('status ASC').each do |domain_category|
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
        ::Integrations::JiraAccountConfig.perform_async(args)
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
    end

    def delete_files(account)
      account.attachments.find_in_batches(batch_size: 30) do |attachments|
        attachments.each do |attachment|
          begin
            prefix = "data/helpdesk/attachments/#{Rails.env}/#{attachment.id}/"
            objects = AwsWrapper::S3.find_with_prefix(S3_CONFIG[:bucket], prefix)

            objects.each do |object|
              object.delete if object.key.include?(attachment.content_file_name)
            end
          rescue StandardError => e
            Rails.logger.info "Unable to delete attachment data from S3. #{e.message}, #{e.backtrace}"
          end
        end
      end
    end

    def clear_archive_data_from_s3(account)
      begin
        ARCHIVE_S3_BUCKET_MAPPING.each do |association_type, s3_bucket|
          account.safe_send(association_type).find_in_batches do |assn|
            db_ids = assn.map(&:id)
            s3_keys = db_ids.inject([]) do |keys,db_id|
              if association_type == :archive_tickets
                keys << Helpdesk::S3::ArchiveTicket::Body.generate_file_path(account.id, db_id)
              elsif association_type == :archive_notes
                keys << Helpdesk::S3::ArchiveNote::Body.generate_file_path(account.id, db_id)
              end
            end
            AwsWrapper::S3.batch_delete(S3_CONFIG[s3_bucket], s3_keys)
          end
        end
      rescue Exception => e
        Rails.logger.info "Unable to delete data from S3. #{e.message}"
      end
    end

    def remove_whitelist_users(account_id)
      WhitelistUser.where(account_id: account_id).delete_all
      clear_whitelist_users_cache
    end

    def remove_remote_integration_mappings(account_id)
      RemoteIntegrationsMapping.where(account_id: account_id).delete_all
    end

    def remove_round_robin_redis_info(account)
      account.groups.find_each do |group|
        group.remove_round_robin_data(group.agents.pluck(:id))
      end
    end

    def delete_account_from_fluffy(account)
      account.destroy_fluffy_account
    rescue => e
      Rails.logger.info("FLUFFY Account deletion failed #{e.message}, #{e.backtrace}")
    end

    def remove_card_info(account)
      if account.try(:subscription).try(:card_number).present?
        Billing::Subscription.new.remove_credit_card(account.id)
      end
    rescue ChargeBee::InvalidRequestError => e
      Rails.logger.info("ChargeBee Card deletion failed #{e.message}, #{e.backtrace}")
    end

    def remove_addon_mapping(account)
      Subscription::AddonMapping.destroy_all(:account_id => account.id)
    end

    def delete_data_from_tables(account_id)
      return if account_id.blank?
      HELPKIT_TABLES.each { |table_name| 
        delete_in_batches(account_id, table_name, DELETE_BATCH_COUNT) do 
          find_db_lag
        end
      }
    end

    def delete_data_from_tables_without_id(account_id)
      HELPKIT_TABLES_AND_COMPOSITE_KEYS.each_key do |table_name|
        composite_key = HELPKIT_TABLES_AND_COMPOSITE_KEYS[table_name]
        delete_data_from_tables_with_composite_key(account_id, table_name, composite_key, DELETE_BATCH_COUNT) do 
          find_db_lag
        end
      end
    end

    def find_db_lag
      lag = get_replication_lag_for_shard(APPLICATION_NAME, @shard_name)
      raise ReplicationLagError.new(lag) if lag > 0
    end

    def remove_from_spam_detection_service(account)
      result = FdSpamDetectionService::Service.new(account.id).delete_tenant
      Rails.logger.info "Response for deleting tenant in SDS: #{result}"
    end

    def publish_account_destroy_to_central(account)
      account.save_deleted_model_info
      account.manual_publish_to_central(nil,:destroy,nil,false)
    end

    # This method will trigger destroy callback and delete forms in service side.
    def delete_canned_forms(account)
      account.canned_forms.each(&:destroy) if account.canned_forms_enabled?
    end

    def delete_widget_data_from_s3(account)
      return unless account.help_widget_enabled?
      widget_ids = account.help_widgets.pluck(:id)
      s3_keys = widget_ids.map { |hid|  
        [
          HelpWidget::FILE_PATH % { :widget_id => hid }, 
          HelpWidget::ZERO_BYTE_FILE_PATH % { :widget_id => hid }
        ]
      }.flatten
      AwsWrapper::S3.batch_delete(S3_CONFIG[:help_widget_bucket], s3_keys)
    rescue Exception => e
      Rails.logger.info "Unable to delete widget data from S3. #{e.message}"
    end
end
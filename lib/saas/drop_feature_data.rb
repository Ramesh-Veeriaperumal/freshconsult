module SAAS::DropFeatureData
  include Marketplace::ApiMethods
  include Marketplace::HelperMethods
  include Solution::Constants
  include ::AgentAssist::Util

  def handle_multi_timezone_drop_data
    UpdateTimeZone.perform_async(time_zone: account.time_zone)
  end

  def handle_round_robin_drop_data
    Role.remove_manage_availability_privilege account
  end

  def handle_article_versioning_drop_data
    ::Solution::ArticleVersionsMigrationWorker.perform_async(action: 'drop')
  end

  def handle_custom_domain_drop_data
    account.main_portal.portal_url = nil
    account.save!
  end

  def handle_layout_customization_drop_data
    account.portal_pages.destroy_all
    account.portal_templates.each do |template|
      template.update_attributes(header: nil, footer: nil, layout: nil, head: nil)
    end
  end

  def handle_advanced_twitter_drop_data
    Social::TwitterHandle.drop_advanced_twitter_data(account)
  end

  def handle_advanced_facebook_drop_data
    # we need to keep one fb page. So removing everything except the oldest one.
    fb_pages = account.facebook_pages.order('created_at asc')
    fb_pages.each_with_index do |fb_page, index|
      next if index.zero?

      begin
        Rails.logger.debug "Facebook page : #{fb_page.inspect} is being deleted"
        fb_page.destroy
      rescue StandardError => e
        Rails.logger.error "Error while removing facebook page: #{e.backtrace}"
      end
    end
  end

  def handle_css_customization_drop_data
    update_all_in_batches(custom_css: nil, updated_at: Time.now) do |cond|
      account.portal_templates.where(@conditions).limit(@batch_size).update_all(cond)
    end
    handle_layout_customization_drop_data
  end

  def handle_custom_roles_drop_data
    account.technicians.each do |agent|
      new_roles = if agent.privilege?(:manage_account)
                    # Array is returned. So removing the []
                    account.roles.account_admin
                  elsif agent.roles.exists?(default_role: true)
                    agent.roles.default_roles
                  else
                    # Array is returned. So removing the []
                    account.roles.agent
                  end
      agent.roles = new_roles
      agent.save
    end

    Role.destroy_all(account_id: account.id, default_role: false)
  end

  def handle_dynamic_sections_drop_data
    service_task_section_constant = Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_SECTION
    service_task_section = account.sections.where(label: service_task_section_constant).first if account.field_service_management_enabled?

    if account.field_service_management_enabled? && service_task_section.present?
      service_task_section_field_ids = service_task_section.section_fields.map(&:ticket_field_id)
      account.ticket_fields.each do |field|
        field.rollback_section_in_field_options if field.section_field? && !service_task_section_field_ids.include?(field.id)
        if field.field_type != 'default_ticket_type' && field.has_sections?
          field.field_options['section_present'] = false
          field.save
        end
      end
      account.sections.where('label NOT IN (?)', service_task_section_constant).destroy_all
    else
      account.ticket_fields.each do |field|
        field.rollback_section_in_field_options if field.section_field?
        if field.section_dropdown? && field.has_sections?
          field.field_options['section_present'] = false
          field.save
        end
      end
      account.sections.destroy_all
    end
  end

  def handle_helpdesk_restriction_toggle_drop_data
    account.helpdesk_permissible_domains.destroy_all
    account.features.restricted_helpdesk.destroy
  end

  def handle_ticket_templates_drop_data
    account.ticket_templates.where(association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general]).destroy_all
  end

  def handle_custom_survey_drop_data
    if account.default_survey_enabled?
      account.custom_surveys.default.first.activate if account.active_custom_survey_from_cache.present?
    else
      account.custom_surveys.deactivate_active_surveys
    end
  end

  def handle_mailbox_drop_data
    account.imap_mailboxes.destroy_all
    account.smtp_mailboxes.destroy_all
  end

  def handle_round_robin_load_balancing_drop_data
    account.groups.capping_enabled_groups.find_each do |group|
      group.capping_limit = 0
      group.save
    end
  end

  def handle_marketplace_drop_data
    account.installed_applications.each do |installed_application|
      begin
        account.destroy_all_slack_rule if installed_application.application.slack?
        installed_application.destroy
      rescue StandardError => e
        Rails.logger.error "Exception while destroying the installed app: \
        #{installed_application.id}, app_id: #{application_id}, Error: \
        #{e.message}, #{e.backtrace.join("\n\t")}"
      end
    end
    installed_apps = fetch_installed_extensions(
      account.id,
      Marketplace::Constants::EXTENSION_TYPE.values
    )
    return if installed_apps.blank?

    installed_apps.map { |ext| ext['extension_id'] }.each do |extension_id|
      @extension = fetch_extension_details(extension_id)
      if @extension.present?
        log_on_error uninstall_extension({
          extension_id: extension_id,
          account_full_domain: account.full_domain
        }.merge!(paid_app_params))
      end
    end
  end

  def handle_scenario_automation_drop_data
    account.scn_automations.each do |scenario_automation|
      begin
        scenario_automation.destroy
      rescue StandardError => e
        Rails.logger.error "Exception while destroying scenario automation rule: \
        #{scenario_automation.id}, account id:#{scenario_automation.account_id}, \
        error: #{e.message}, backtrace: #{e.backtrace}"
      end
    end
  end

  def handle_custom_password_policy_drop_data
    account.agent_password_policy.reset_policies.save!
    account.contact_password_policy.reset_policies.save!
  end

  def handle_personal_canned_response_drop_data
    personal_folder = account.canned_response_folders.personal_folder.first
    personal_folder.canned_responses.each(&:destroy)
  end

  def handle_public_url_toggle_drop_data
    account.features.public_ticket_url.destroy
  end
  
  def handle_agent_scope_drop_data
    account.agents.each do |agent|
      begin
        agent.reset_ticket_permission
        agent.save!
      rescue Exception => e
        Rails.logger.info "Exception while saving agent.. #{e.backtrace}"
      end
    end
  end

  def handle_custom_translations_drop_data
    Account.current.custom_translations.find_each(&:destroy)
  end

  def handle_suggested_articles_count_drop_data
    account.solution_articles.where('int_01 > 0').find_each do |article|
      article.suggested = 0
      article.save
    end
  end

  def handle_segments_drop_data
    account.solution_folder_meta.where(visibility: [VISIBILITY_KEYS_BY_TOKEN[:contact_segment], VISIBILITY_KEYS_BY_TOKEN[:company_segment]]).find_each do |folder_meta|
      folder_meta.visibility = VISIBILITY_KEYS_BY_TOKEN[:company_users]
      folder_meta.save
    end
  end

  def handle_article_approval_workflow_drop_data
    account.helpdesk_approvals.solution_approvals.find_each do |approval|
      begin
        approval.destroy
      rescue Exception => e # rubocop:disable Lint/RescueException
        Rails.logger.info "Exception while deleting approval [#{approval.account_id}, #{approval.id}]: #{e.backtrace}"
      end
    end
  end

  def handle_solutions_templates_drop_data
    ::Solution::TemplatesMigrationWorker.perform_async(action: 'drop')
  end

  def handle_agent_assist_ultimate_drop_data
    drop_agent_assist_ultimate
  end

  def handle_agent_assist_lite_drop_data
    drop_agent_assist_lite
  end
end

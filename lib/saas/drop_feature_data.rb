module SAAS::DropFeatureData
  def handle_multi_timezone_drop_data
    UpdateTimeZone.perform_async(time_zone: account.time_zone)
  end

  def handle_round_robin_drop_data
    Role.remove_manage_availability_privilege account
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
    account.ticket_fields.each do |field|
      field.rollback_section_in_field_options if field.section_field?
      if field.section_dropdown? && field.has_sections?
        field.field_options['section_present'] = false
        field.save
      end
    end
    account.sections.destroy_all
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
end

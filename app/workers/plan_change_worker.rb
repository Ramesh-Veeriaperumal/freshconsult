class PlanChangeWorker
  include Sidekiq::Worker
  include Cache::FragmentCache::Base


  sidekiq_options :queue => :plan_change, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    account = Account.current
    args.symbolize_keys!
    features  = args[:features]
    action    = args[:action]

    features.each do |feature|
      method = "#{action}_#{feature}_data"
      # Adding this block due to dynamic sections bug
      # Ref: https://github.com/freshdesk/helpkit/commit/7da2749537bfac540bbf8495d144e8a68c9c9e0d
      #
      begin
        send(method, account) if respond_to?(method)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end
  end

  def add_round_robin_data(account)
    Role.add_manage_availability_privilege account
  end

  def drop_round_robin_data(account)
    Role.remove_manage_availability_privilege account
  end

  def add_multiple_companies_toggle_data(account)
    unless account.ticket_fields.default_company_field.present?
      account.ticket_fields.create(:name => "company",
                                   :label => "Company",
                                   :label_in_portal => "Company",
                                   :description => "Ticket Company",
                                   :field_type => "default_company",
                                   :position => account.ticket_fields.length+1,
                                   :default => true,
                                   :required => true,
                                   :visible_in_portal => true, 
                                   :editable_in_portal => true,
                                   :required_in_portal => true,
                                   :ticket_form_id => account.ticket_field_def.id)
      clear_fragment_caches
    end
  end

  def drop_facebook_data(account)
    fb_count = 0
    account.facebook_pages.order("created_at asc").find_each do |fb|
      next if fb_count < 1
      fb.destroy
      fb_count+=1
    end

  end

  def drop_twitter_data(account)
    twitter_count = 0
    account.twitter_handles.order("created_at asc").find_each do |twitter|
      next if twitter_count < 1
      twitter.destroy
      twitter_count+=1
    end
  end

  def drop_custom_domain_data(account)
    account.main_portal.portal_url = nil
    account.save!
  end

  def drop_layout_customization_data(account)
    account.portal_pages.destroy_all
    account.portal_templates.each do |template|
      template.update_attributes( :header => nil, :footer => nil, :layout => nil, :head => nil)
    end
  end

  def drop_css_customization_data(account)
    update_all_in_batches({ :custom_css => nil, :updated_at => Time.now }){ |cond|
      account.portal_templates.where(@conditions).limit(@batch_size).update_all(cond)
    }
    drop_layout_customization_data(account)
  end

  def drop_custom_roles_data(account)
    account.technicians.each do |agent|
      if agent.privilege?(:manage_account)
        #Array is returned. So removing the []
        new_roles = account.roles.account_admin
      elsif agent.roles.exists?(:default_role => true)
        new_roles = agent.roles.default_roles
      else
        #Array is returned. So removing the []
        new_roles = account.roles.agent
      end
      agent.roles = new_roles
      agent.save
    end

    Role.destroy_all(:account_id => account.id, :default_role => false )
  end

  def drop_dynamic_sections_data(account)
    account.ticket_fields.each do |field|
      if field.section_field?
        field.rollback_section_in_field_options
      end
      if field.section_dropdown? && field.has_sections?
        field.field_options["section_present"] = false
        field.save
      end
    end
    account.sections.destroy_all
  end

  def drop_helpdesk_restriction_toggle_data(account)
    account.helpdesk_permissible_domains.destroy_all
    account.features.restricted_helpdesk.destroy
  end

  def drop_ticket_templates_data(account)
    account.ticket_templates.where(:association_type =>
      Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general]).destroy_all
  end

  def drop_custom_survey_data(account)
    if account.default_survey_enabled?
      account.custom_surveys.default.first.activate if account.active_custom_survey_from_cache.present?
    else
      account.custom_surveys.deactivate_active_surveys
    end
  end

  def drop_dynamic_content_data(account)
    # update_all_in_batches({ :language => account.language }){ |cond|
    #   account.all_users.where(@conditions).limit(@batch_size).update_all(cond)
    # }
    # Below line has been intentionally commented, as we want to make sure,
    # when the customer upgrades again, he'll have all the data and config as it was before. [Solution Multilingual Feature]
    #account.account_additional_settings.update_attributes(:supported_languages => [])
  end

  def drop_mailbox_data(account)
    account.imap_mailboxes.destroy_all
    account.smtp_mailboxes.destroy_all
  end

  def drop_multi_language_data(account)
    return true
    # Below line has been intentionally commented, as we want to make sure,
    # when the customer upgrades again, he'll have all the data and config as it was before. [Solution Multilingual Feature]
    # return unless account.features_included?(:enable_multilingual)
    # { 
    #   :solution_articles => 'Solution::Article',
    #   :solution_folders => 'Solution::Folder',
    #   :solution_categories => 'Solution::Category'
      
    # }.each do |solution_entity, entity_class|
    #   account.send(solution_entity).where(["language_id NOT IN (?)", [Account.current.language_object.id]]).destroy_all
    # end
    # account.remove_feature(:enable_multilingual)
    # new_settings = account.account_additional_settings.additional_settings.merge(:portal_languages => [])
    # account.account_additional_settings.update_attributes(:additional_settings => new_settings)
  end

  def drop_round_robin_load_balancing_data(account)
    account.groups.capping_enabled_groups.find_each do |group|
      group.capping_limit = 0
      group.save
    end
  end

=begin
  @conditions, @batch size are created using VALUES hash that is passed
  If need to check additional conditions, pass in a where that is prepended before the where using @conditions

  Invocation:
  update_all_in_batches(VALUES) { |c| account.users.where(@conditions).limit(@batch_size).update_all(c) }
=end

  def update_all_in_batches(change_hash)
    change_hash.symbolize_keys!
    frame_conditions(change_hash)
    begin
      updated_count = yield(change_hash)
    end while updated_count == @batch_size
    nil
  end

  def frame_conditions(change_hash)
    # Excluding created_at, updated_at as != is bad check
    @conditions = [[]]
    @batch_size = change_hash.delete(:batch_size) || 500
    change_hash.except(:created_at, :updated_at).each do |key ,value|
      if value.nil?
        @conditions[0] << "`#{key}` is not null"
      else
        @conditions[0] << "`#{key}` != ?"
        @conditions << value
      end
    end
    @conditions[0] = @conditions[0].join(" and ")
    nil
  end
end

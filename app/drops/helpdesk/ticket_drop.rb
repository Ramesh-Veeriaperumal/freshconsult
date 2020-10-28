class Helpdesk::TicketDrop < BaseDrop

  include Rails.application.routes.url_helpers
  include TicketConstants
  include DateHelper

  self.liquid_attributes += [ :group , :ticket_type , :deleted, :internal_group ]
  DYNAMIC_LIQUID_METHODS = ["canned_form"]

  attr_accessor :dynamic_method_name, :dynamic_method_id

  def initialize(source)
    super source
  end

  def subject
    escape_liquid_attribute(@source.subject)
  end

  def id
    @source.display_id
  end

  def raw_id
    @source.id
  end

  def from_email
    @source.from_email
  end

  def group_id
    @source.group_id
  end

  def encode_id
    @source.encode_display_id
  end

  def description
    @description_with_attachments ||= @source.description_with_attachments
  end

  def description_text
    @source.description
  end

  def description_html
    @source.description_html
  end

  def attachments
      @source.all_attachments
  end

  def cloud_files
      @source.cloud_files
  end

  #Escaping for associated objects having custom fields.
  ["requester", "company"].each do |assoc|
    define_method(assoc) do
      return instance_variable_get("@#{assoc}") if instance_variable_defined?("@#{assoc}")
      current_assoc = @source.safe_send(assoc).presence
      if current_assoc
        current_assoc.escape_liquid_attributes = @source.escape_liquid_attributes
      end
      instance_variable_set("@#{assoc}", current_assoc)
    end
  end

  def outbound_initiator
    @source.outbound_initiator.presence
  end

  def outbound_email?
    @source.outbound_email?
  end

  def agent
    @source.responder.presence
  end

  def friendly_email_replies?
    !@source.account.has_feature?(:personalized_email_replies)
  end

  def primary_email_name
    @source.product.try(:primary_email_config) ? @source.product.primary_email_config.name : @source.account.primary_email_config.name
  end

  def internal_agent
    @source.internal_agent.presence
  end

  def status
    @source.status_name
  end

  def status_id
    @source.status
  end

  def requester_status_name
    @source.requester_status_name
  end

  def priority
    TicketConstants.priority_list[@source.priority]
  end

  def priority_id
    @source.priority
  end

  def source
    if @source.account.ticket_source_revamp_enabled?
      @source.source_name
    else
      TicketConstants.source_list[@source.source]
    end
  end

  def source_id
    @source.source
  end

  def source_name
    @source.source_name
  end

  def tags
    @source.tag_names.join(', ')
  end

  def due_by_time_raw
    in_user_time_zone(@source.due_by)
  end

  def fr_due_by_time_raw
    in_user_time_zone(@source.frDueBy)
  end
  
  def due_by_time
    if @source.account.sla_management_v2_enabled?
      in_user_time_zone(@source.due_by).strftime('%B %e %Y at %I:%M %p %Z')
    else
      ''
    end
  end

  def due_by_hrs
    in_user_time_zone(@source.due_by).strftime("%I:%M %p %Z")
  end

  def fr_due_by_time
    in_user_time_zone(@source.frDueBy).strftime("%B %e %Y at %I:%M %p %Z")
  end

  def fr_due_by_hrs
    in_user_time_zone(@source.frDueBy).strftime("%I:%M %p %Z")
  end

  def nr_due_by_hrs
    in_user_time_zone(@source.nr_due_by).strftime("%I:%M %p %Z") if @source.nr_due_by.present?
  end

  def nr_remaining_time
    Time.at(@source.nr_due_by - Time.zone.now.utc).utc.strftime("%H hr %M min %S sec") if @source.nr_due_by.present?
  end

  def cf_fsm_appointment_start_time
    start_time = "#{FSM_DATE_TIME_FIELDS[:start_time]}_#{@source.account.id}"
    in_portal_time_zone(@source.custom_field[start_time]).strftime('%B %e %Y at %I:%M %p %Z')
  end

  def cf_fsm_appointment_end_time
    end_time = "#{FSM_DATE_TIME_FIELDS[:end_time]}_#{@source.account.id}"
    in_portal_time_zone(@source.custom_field[end_time]).strftime('%B %e %Y at %I:%M %p %Z')
  end

  def sla_policy_name
    @source.sla_policy_name.to_s
  end

  def url
    helpdesk_ticket_url(@source, :host => @source.account.host, :protocol=> @source.url_protocol)
  end

  def full_domain_url
    support_ticket_url(@source, :host => @source.account.full_domain, :protocol=> @source.url_protocol)
  end

  def public_url
    return "" if !@source.account.features_included?(:public_ticket_url) || @source.account.hipaa_and_encrypted_fields_enabled?

    access_token = @source.access_token.blank? ? @source.get_access_token : @source.access_token

    public_ticket_url(access_token,:host => @source.portal_host, :protocol=> @source.url_protocol)
  end

  def portal_url
    support_ticket_url(@source, :host => @source.portal_host, :protocol=> @source.url_protocol)
  end

  def portal_name
    @source.portal_name
  end

  def product_description
    @source.product ? @source.product.description : ""
  end

  def latest_public_comment
    @last_public_comment ||= @source.liquidize_comment(@source.latest_public_comment, true)
  end

  def latest_private_comment
    @last_private_comment ||= @source.liquidize_comment(@source.latest_private_comment, true)
  end

  def latest_public_comment_text
    @last_public_comment_text ||= @source.liquidize_comment(@source.latest_public_comment, false)
  end

  def latest_private_comment_text
    @last_private_comment_text ||= @source.liquidize_comment(@source.latest_private_comment, false)
  end

  def public_comments
    # source.notes.public.exclude_source('meta').newest_first
    @source.public_notes.exclude_source(Account.current.helpdesk_sources.note_exclude_sources).oldest_first
  end

  def billable_hours
    @billable_hours ||= @source.billable_hours
  end

  def total_time_spent
    @formatted_time ||= @source.time_tracked_hours
  end

  def satisfaction_survey
    @satisfaction_survey ||= begin
      if @source.account.new_survey_enabled?
        CustomSurvey::Survey.satisfaction_survey_html(@source)
      else
        Survey.satisfaction_survey_html(@source)
      end
    end
  end

  def surveymonkey_survey
    Integrations::SurveyMonkey.survey_html(@source)
  end

  def in_user_time_zone(time)
    portal_user_or_account = (portal_user || portal_account)
    portal_user_or_account.blank? ? time : time.in_time_zone(portal_user_or_account.time_zone)
  end

  def in_portal_time_zone(time)
    time.in_time_zone(portal_account.time_zone)
  end

  def created_on
    @source.created_at
  end

  def modified_on
    @source.updated_at
  end

  def status_changed_on
    @source.ticket_states.status_updated_at
  end

  def freshness
    @source.freshness.to_s
  end

  def close_ticket_url
    @close_ticket_url ||= close_support_ticket_path(@source, :host => @source.portal_host, :protocol=> @source.url_protocol)
  end

  def closed?
    @source.closed?
  end

  def active?
    @source.active?
  end

  def parent_ticket_id
    @source.child_ticket? ? @source.associates_rdb : nil
  end

  def tracker_ticket_id
    @source.related_ticket? ? @source.associates_rdb : nil
  end

  def before_method(method)
    field_name = "#{method}_#{@source.account_id}"
    @field_mappings ||= @source.custom_field_type_mappings
    required_field_type = @field_mappings[field_name]
    required_field_value = @source.custom_field[field_name]
    # required_field_value will be present only for custom field
    return formatted_field_value(required_field_type, required_field_value) if required_field_value 
    return safe_send(dynamic_method_name.to_s.to_sym, dynamic_method_id) if dynamic_liquid_method?(method)
    return super
  end

  def dynamic_liquid_method?(method)
    @dynamic_method_id = method.to_s.split("_")[-1]
    @dynamic_method_name = method.to_s.split("_" + dynamic_method_id)[0]
    (DYNAMIC_LIQUID_METHODS.include? dynamic_method_name) && (method == dynamic_method_name + "_" + dynamic_method_id)
  end

  def canned_form(cf_id)
    cf_obj = Account.current.canned_forms.find(cf_id)
    cf_handle = @source.create_or_fetch_canned_form(cf_obj)
    cf_support_url = cf_handle.try(:handle_url)
    return "<a href=#{cf_support_url}> #{cf_obj.name}</a>" if cf_support_url
  end

  def current_portal
    @portal
  end

  def cc_content
    CcViewHelper.new(@source, @source.cc_email_hash[:tkt_cc], @source.cc_email_hash[:dropped_cc_emails]).cc_content
  end

  def portal
    @source.portal
  end
  alias_method :contact, :requester
end

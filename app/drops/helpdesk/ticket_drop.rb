class Helpdesk::TicketDrop < BaseDrop

  include Rails.application.routes.url_helpers
  include TicketConstants
  include DateHelper

  self.liquid_attributes += [ :requester , :group , :ticket_type , :deleted, :company, :internal_group ]

  def initialize(source)
    super source
  end

  def subject
    h(@source.subject)
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

  def freshfone_call
    @source.freshfone_call
  end

  def cloud_files
      @source.cloud_files
  end

  def requester
    @source.requester.presence
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
    TicketConstants.source_list[@source.source]
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
    in_user_time_zone(@source.due_by).strftime("%B %e %Y at %I:%M %p %Z")
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
    return "" unless @source.account.features_included?(:public_ticket_url)

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
    @source.public_notes.exclude_source('meta')
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

  def before_method(method)
    field_name = "#{method}_#{@source.account_id}"
    required_field_value = @source.custom_field[field_name]
    required_field_type = @source.custom_field_type_mappings[field_name]
    return super unless required_field_type
    formatted_field_value(required_field_type.to_sym, required_field_value)
  end

  def current_portal
    @portal
  end

  def cc_content
    CcViewHelper.new(@source, @source.cc_email_hash[:tkt_cc], @source.cc_email_hash[:dropped_cc_emails]).cc_content
  end

end

module Freshcaller::CallConcern
  extend ActiveSupport::Concern

  RECORDING_STATUS_HASH = {
    invalid: 0,
    'in-progress': 1,
    completed: 2,
    deleted: 3
  }

  include Search::V2::AbstractController

  def ticket_params
    params_hash = { source: current_account.helpdesk_sources.ticket_source_keys_by_token[:phone],
                    subject: ticket_title,
                    phone: @options[:customer_number],
                    name: @options[:customer_number],
                    cc_email: Helpdesk::Ticket.default_cc_hash,
                    ticket_body_attributes: { description_html: description, description: description } }
    params_hash = params_hash.merge(requester_id: @contact.id) if @contact.present?
    params_hash = params_hash.merge(meta_data: { 'created_by' => @creator.id }, responder_id: @agent.id) if @agent.present?
    params_hash
  end

  def update_ticket_params
    params_hash = { subject: ticket_title,
                ticket_body_attributes: { description_html: description, description: description } }
    params_hash
  end

  def note_params
    user_id = @agent.present? ? @agent.id : account_admin_id
    {
      user_id: user_id,
      private: true,
      source: current_account.helpdesk_sources.note_source_keys_by_token['note'],
      note_body_attributes: { body_html: "#{description} #{duration} #{call_notes}" }
    }
  end

  def call_info
    {
      description: description,
      duration: duration,
      call_notes: call_notes
    }
  end

  def load_contact_from_search
    @klasses = ['User']
    @search_context = :ff_contact_by_numfields
    @es_search_term = @options[:customer_number]
    results = esv2_query_results({'user' => { model: 'User' }})
    results.first if results.length > 0
  end

  def load_contact_from_number
    Sharding.run_on_slave do
      current_account.all_users.where(phone: @customer_number).first
    end
  end

  def account_admin_id
    current_account.roles.account_admin.first.users.first.id
  end

  def non_attended_call?
    missed_call? || abandoned? || voicemail?
  end

  def incoming_missed_call?
    missed_call? && @options[:call_type] == 'incoming'
  end
  
  def outgoing_missed_call?
    missed_call? && @options[:call_type] == 'outgoing'
  end

  def missed_call?
    @options[:call_status] == 'no-answer'
  end

  def abandoned?
    @options[:call_status] == 'abandoned'
  end

  def voicemail?
    @options[:call_status] == 'voicemail'
  end

  def completed?
    @options[:call_status] == 'completed'
  end

  def ongoing?
    ['in-progress', 'on-hold', 'default'].include?(@options[:call_status])
  end

  def missed_callback?
    callback? && (missed_call? || abandoned?)
  end

  def callback_parent?
    @options[:ancestry].blank? && callback?
  end

  def ticket_title
    @options[:subject] || generate_title
  end

  def call_notes?
    @options[:note].present?
  end

  def fc_account
    @fc_account ||= current_account.freshcaller_account
  end

  def auto_ticket_creation_enabled?
    missed_call_auto_ticket_enabled? || abandoned_call_auto_ticket_enabled? || connected_call_auto_ticket_enabled?
  end

  def missed_call_auto_ticket_enabled?
    fc_account.missed_call_auto_ticket_enabled? && (incoming_missed_call? || outgoing_missed_call? || voicemail?) && !callback_parent?
  end

  def abandoned_call_auto_ticket_enabled?
    fc_account.abandoned_call_auto_ticket_enabled? && abandoned?
  end

  def connected_call_auto_ticket_enabled?
    fc_account.connected_call_auto_ticket_enabled? && (ongoing? || (completed? && !callback_parent?))
  end

  def generate_title
    call_date = DateTime.parse(@options[:call_created_at]).in_time_zone(current_account.time_zone)
    return I18n.t("call.ticket.callback_#{call_status_string}_title", customer: customer_title) if missed_callback?
    return I18n.t("call.ticket.#{call_status_string}_title", customer: customer_title) if abandoned?
    return I18n.t("call.ticket.#{@options[:call_type]}_#{call_status_string}_title", customer: customer_title) if missed_call?
    return I18n.t("call.ticket.#{call_status_string}_title", customer: customer_title) if voicemail?
    I18n.t("call.ticket.#{call_status_string}_title", type: @options[:call_type].camelize, customer: customer_title, date: call_date.strftime('%a, %b %d'),
                                                      time: call_date.strftime('%I:%M:%S %p'))
  end

  def customer_title
    @contact.present? ? @contact.name : @options[:customer_number]
  end

  def customer_details
    return "#{@contact.name} (#{@options[:customer_number]}, #{@options[:customer_location]})" if @contact.present? && @contact.name != @options[:customer_number]
    return "#{@options[:customer_number]} (#{@options[:customer_location]})" if @options[:customer_location].present?
    @options[:customer_number]
  end

  def agent_details
    return "#{@call_agent.name} (#{@options[:agent_number]})" if @call_agent.present?

    @options[:agent_number]
  end

  def description
    @options[:description] || generate_description
  end

  def generate_description
    return I18n.t("call.ticket.callback_#{call_status_string}_description", customer: customer_details) if missed_callback?
    return I18n.t("call.ticket.#{call_status_string}_description", customer: customer_details, agent: agent_details) if abandoned?
    return I18n.t("call.ticket.#{@options[:call_type]}_#{call_status_string}_description", customer: customer_details, agent: agent_details) if missed_call?
    I18n.t("call.ticket.#{call_status_string}_description", customer: customer_details, agent: agent_details)
  end

  def callback?
    @options[:callback]
  end

  def call_notes
    I18n.t('call.note_html', call_note: @options[:note]) if call_notes?
  end

  def duration
    I18n.t('call.duration_html', call_duration: formatted_duration) if @options[:duration].present?
  end

  def call_status_string
    @options[:call_status].delete('-')
  end

  def formatted_duration
    format = (@options[:duration] < 3600) ? '%M:%S' : '%H:%M:%S'
    Time.at(@options[:duration]).utc.strftime(format)
  end

  def merge_ticket_params(primary, secondary)
    {
      note_in_primary: {
        body: I18n.t('helpdesk.merge.bulk_merge.target_merge_description1', ticket_id: secondary.display_id, full_domain: secondary.portal.host),
        private: true
      },
      note_in_secondary: {
        body: I18n.t('helpdesk.merge.confirm_merge.source_merge_description', ticket_id: primary.display_id, full_domain: primary.portal.host),
        private: true
      },
      convert_recepients_to_cc: false
    }
  end
end

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
    params_hash = { source: TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone],
                subject: ticket_title,
                created_at: @options[:call_created_at],
                phone: @options[:customer_number],
                name: @options[:customer_number],
                ticket_body_attributes: { description_html: description, description: description } }
    params_hash = params_hash.merge(requester_id: @contact.id) if @contact.present?
    params_hash = params_hash.merge(meta_data: { 'created_by' => @agent.id }, responder_id: @agent.id) if @agent.present?
    params_hash
  end

  def note_params
    user_id = @agent.present? ? @agent.id : account_admin_id
    {
      user_id: user_id,
      private: true,
      source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
      note_body_attributes: { body_html: "#{description} #{duration} #{call_notes}" }
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

  def incoming_missed_call?
    missed_call? && @options[:call_type] == 'incoming'
  end
  
  def outgoing_missed_call?
    missed_call? && @options[:call_type] == 'outgoing'
  end

  def missed_call?
    @options[:call_status] == 'no-answer'
  end

  def voicemail?
    @options[:call_status] == 'voicemail'
  end

  def completed?
    @options[:call_status] == 'completed'
  end

  def inprogress?
    @options[:call_status] == 'in-progress'
  end

  def on_hold?
    @options[:call_status] == 'on-hold'
  end

  def ticket_title
    @options[:subject] || generate_title
  end

  def generate_title
    call_date = DateTime.parse(@options[:call_created_at]).in_time_zone(current_account.time_zone)
    return I18n.t("call.ticket.#{@options[:call_type]}_#{call_status_string}_title", customer: customer_title) if missed_call?
    return I18n.t("call.ticket.#{call_status_string}_title", customer: customer_title) if voicemail?
    I18n.t("call.ticket.#{call_status_string}_title", customer: customer_title, date: call_date.strftime('%a, %b %d'),
                                                      time: call_date.strftime('%I:%M:%S %p'))
  end

  def customer_title
    @contact.present? ? @contact.name : @options[:customer_number]
  end

  def customer_details
    return "#{@contact.name} ( #{@options[:customer_number]} ,#{@options[:customer_location]} )" if @contact.present? && @contact.name != @options[:customer_number]
    return "#{@options[:customer_number]} ( #{@options[:customer_location]} )" if @options[:customer_location].present?
    @options[:customer_number]
  end

  def agent_details
    return "#{@agent.name} ( #{@options[:agent_number]} )" if @agent.present?
    @options[:agent_number]
  end

  def description
    @options[:description] || generate_description
  end

  def generate_description
    return I18n.t("call.ticket.#{@options[:call_type]}_#{call_status_string}_description", customer: customer_details, agent: agent_details) if missed_call?
    I18n.t("call.ticket.#{call_status_string}_description", customer: customer_details, agent: agent_details)
  end

  def call_notes
    I18n.t('call.note_html', call_note: @options[:note]) if @options[:note].present?
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
end

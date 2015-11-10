class Freshfone::Call < ActiveRecord::Base
  include Freshfone::FreshfoneUtil
  include ApplicationHelper
  include Mobile::Actions::Freshfone
  include Freshfone::CallerLookup
  self.table_name =  :freshfone_calls
  self.primary_key = :id

  serialize :recording_deleted_info, Hash  
  belongs_to :agent, :class_name => '::User', :foreign_key => 'user_id'
  belongs_to_account
  belongs_to :freshfone_number, :class_name => 'Freshfone::Number'
  belongs_to :ticket, :foreign_key => 'notable_id', :class_name => 'Helpdesk::Ticket'
  belongs_to :note, :foreign_key => 'notable_id', :class_name => 'Helpdesk::Note'

  belongs_to :customer, :class_name => '::User', :foreign_key => 'customer_id'

  belongs_to :notable, :polymorphic => true, :validate => true

  belongs_to :caller, :class_name => 'Freshfone::Caller', :foreign_key => 'caller_number_id'

  belongs_to :group

  has_one :meta, :class_name => 'Freshfone::CallMeta', :dependent => :destroy

  has_ancestry :orphan_strategy => :destroy

  before_save   :update_call_changes
  after_commit :recording_attachment_job, on: :update, :if => :trigger_recording_job?

  has_one :recording_audio, :as => :attachable, :class_name => 'Helpdesk::Attachment', :dependent => :destroy

  delegate :number, :to => :freshfone_number
  delegate :name, :to => :agent, :allow_nil => true, :prefix => true
  delegate :name, :to => :customer, :allow_nil => true, :prefix => true

  attr_protected :account_id
  attr_accessor :params
  
  VOICEMAIL_MAX_LENGTH = 180 #seconds
  RECORDING_MAX_LENGTH = 300

  CALL_STATUS = [
    [ :default, 'default', 0 ],
    [ :answered,  'answered', 1 ],
    [ :completed, 'completed',  1 ],
    [ :busy,  'busy', 2 ],
    [ :'no-answer', 'missed call',  3 ],
    [ :failed,  'call failed',  4 ],
    [ :canceled,  'call canceled',  5 ],
    [ :queued,  'queued', 6 ],
    [ :ringing, 'ringing',  7 ],
    [ :'in-progress', 'in-progress', 8 ],
    [ :blocked, 'blocked', 9 ],
    [ :voicemail, 'voicemail', 10 ],
    [ :restricted, 'restricted', 11],
    [ :'on-hold', 'on hold', 12 ],
    [ :'connecting', 'connecting', 13 ]
  ]

  CALL_STATUS_HASH = Hash[*CALL_STATUS.map { |i| [i[0], i[2]] }.flatten]
  CALL_STATUS_REVERSE_HASH = Hash[*CALL_STATUS.map { |i| [i[2], i[0]] }.flatten]
  CALL_STATUS_STR_HASH = Hash[*CALL_STATUS.map { |i| [i[0].to_s, i[2]] }.flatten]
  INTERMEDIATE_CALL_STATUS = [
    CALL_STATUS_HASH[:default],
    CALL_STATUS_HASH[:'in-progress'],
    CALL_STATUS_HASH[:'on-hold'],
    CALL_STATUS_HASH[:'connecting'],
    CALL_STATUS_HASH[:queued]
  ]
  CALL_TYPE = [
    [ :incoming,  'incoming', 1 ],
    [ :outgoing,  'outgoing', 2 ]
  ]

  CALL_TYPE_HASH = Hash[*CALL_TYPE.map { |i| [i[0], i[2]] }.flatten]
  CALL_TYPE_REVERSE_HASH = Hash[*CALL_TYPE.map { |i| [i[2], i[0]] }.flatten]
  
  CALL_DIRECTION_STR = {
    :incoming => "From",
    :outgoing => "To"
  }

  EXPORT_RANGE_LIMIT_IN_MONTHS = 6

  CALL_ABANDON_TYPE = [
    [:ringing_abandon, 'Abandon (Ringing)', 0],
    [:ivr_abandon, 'Abandon (IVR)', 1],
    [:queue_abandon, 'Abandon (Queue)', 2]
  ]
  CALL_ABANDON_TYPE_HASH = Hash[*CALL_ABANDON_TYPE.map { |i| [i[0], i[2]] }.flatten]
  CALL_ABANDON_TYPE_REVERSE_HASH = Hash[*CALL_ABANDON_TYPE.map { |i| [i[2], i[0]] }.flatten]
  CALL_ABANDON_TYPE_STR_HASH = Hash[*CALL_ABANDON_TYPE.map { |i| [i[2], i[1].to_s] }.flatten]
  validates_presence_of :account_id, :freshfone_number_id
  validates_inclusion_of :call_status, :in => CALL_STATUS_HASH.values,
    :message => "%{value} is not a valid call status"
  validates_inclusion_of :call_type, :in => CALL_TYPE_HASH.values,
    :message => "%{value} is not a valid call type"



  scope :active_calls, lambda {
    { :conditions => [ 'call_status = ? AND updated_at >= ?', 
        CALL_STATUS_HASH[:'in-progress'], 4.hours.ago.to_s(:db)
      ], :order => "created_at DESC"
    }
  }

  scope :filter_by_call_sid, lambda { |call_sid|
    { :conditions => ["call_sid = ?", call_sid], :order => 'created_at DESC', :limit => 1 }
  }

  scope :filter_by_dial_call_sid, lambda { |dial_call_sid|
    { :conditions => ["dial_call_sid = ?", dial_call_sid], :order => 'created_at DESC', :limit => 1 }
  }

  scope :include_ticket_number, { 
    :include => [ :ticket, :note, :freshfone_number ] }
  scope :include_customer, { :include => [ :customer ] }
  scope :include_agent, { :include => [ :agent ] }
  scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
  scope :active_call, lambda {
    { :conditions => [ 'call_status = ? AND updated_at >= ?', 
        CALL_STATUS_HASH[:default], 1.minute.ago.to_s(:db)
      ], :limit => 1, :order => "created_at DESC"
    }
  }

  scope :agent_progress_calls, lambda { |user_id|
    {:conditions => ["user_id = ? and (call_status in (?) and created_at > ? and created_at < ?)",
          user_id, [CALL_STATUS_HASH[:default], CALL_STATUS_HASH[:'in-progress'], CALL_STATUS_HASH[:'on-hold'], CALL_STATUS_HASH[:connecting]], 4.hours.ago.to_s(:db), Time.zone.now.to_s(:db)
        ], :order => "created_at DESC"
    }
  }

  scope :customer_in_progess_calls, lambda{ |customer_id|
      { :conditions => ["customer_id = ? and (call_status in (?) and created_at > ? and created_at < ?)", customer_id, 
        INTERMEDIATE_CALL_STATUS, 4.hours.ago.to_s(:db), Time.zone.now.to_s(:db)
      ], :order => "created_at DESC"
    }
  }

  scope :created_at_inside, lambda { |start, stop|
    { :conditions => ["freshfone_calls.created_at >= ? and freshfone_calls.created_at <= ?", start, stop] }
  }

  scope :queued_calls, :conditions => [
    'call_status = ? AND updated_at >= ?', 
    CALL_STATUS_HASH[:queued], 1.hours.ago.to_s(:db)
  ]

  def self.filter_call(call_sid)
    call = filter_by_call_sid(call_sid).first
    call.blank? ? filter_by_dial_call_sid(call_sid).first : call
  end
  
  def self.include_all
    self.include_ticket_number.include_customer.include_agent
  end
  
  def self.call_in_progress
    self.active_call.first
  end

  CALL_TYPE_HASH.each_pair do |k, v|
    define_method("#{k}?") do
      call_type == v
    end
  end
  
  CALL_STATUS_HASH.each_pair do |k, v|
    define_method("#{k.to_s.gsub(/\W/, '')}?") do
      call_status == v
    end
  end

  CALL_STATUS_HASH.each_pair do |k, v|
    define_method("#{k.to_s.gsub(/\W/, '')}!") do
      self.call_status = v
      save
    end
  end

  [ :number, :city, :state, :country, :id].each do |type|
    define_method("caller_#{type}") do
      (caller || {})[type]
    end
  end

  def ringing?
    default?
  end

  def can_be_connected?
    ringing? or queued?
  end

  def recording_deleted_by
    user_id = recording_deleted_info[:deleted_by]
    account.users.where({:id => user_id}).pluck(:name).first if user_id.present?
  end

  def recording_deleted_at
    recording_deleted_info[:deleted_at]
  end

  def update_call(params)
    update_call_details(params).save
  end
  
  def update_call_details(params)
    self.params = params 
    self.conference_sid = params[:ConferenceSid] if conference_sid.blank?
    self.dial_call_sid = params[:DialCallSid] if params[:DialCallSid].present?
    self.agent = called_agent(params) if agent.blank?
    self.recording_url = params[:RecordingUrl] if recording_url.blank?
    set_call_duration(params) if !account.features?(:freshfone_conference) && call_duration.blank? # will set duration only for non-conf. mode here
    self.direct_dial_number = params[:direct_dial_number] if ivr_direct_dial?
    update_status(params)
  end

  def update_status(params)
    self.params = params
    if params[:DialCallStatus]
      self.call_status = CALL_STATUS_STR_HASH[params[:DialCallStatus]]
      self.call_status = CALL_STATUS_HASH[:voicemail] if voicemail_ticket?
    elsif default? and params[:force_termination]
      self.call_status = CALL_STATUS_HASH[:'no-answer']
    else
    #   self.call_status = CALL_STATUS_STR_HASH[params[:CallStatus]]
    end
    self
  end

  def update_agent(agent)
    update_attributes(:agent => agent)
  end
  
  def delete_recording(user_id)
    return false if self.recording_url.blank?
    begin
      self.recording_audio.destroy if self.recording_audio.present?
      delete_twilio_recording(user_id)
      self.update_attributes!(build_recording_delete_params(user_id))
    rescue Exception => e
      Rails.logger.debug "Error Deleting the Call Recording for call id:#{self.id}, account id: #{account.id} User Id: #{user_id}
      .\n #{e.message}\n #{e.backtrace.join("\n\t")}"
      raise e
    end
    self.recording_deleted
  end
  
  def location
    [caller_city, caller_state, country_name(caller_country)].reject(&:blank?).join(", ")
  end

  def customer_sid
    outgoing? ? dial_call_sid : call_sid
  end

  def hold_leg_sid # transfer fallback (resume) case. Later we can merge with customer_sid
    outgoing? ? root.dial_call_sid : call_sid
  end

  def agent_sid
    outgoing? ? call_sid : dial_call_sid
  end

  def can_log_agent?
    (incoming? || transferred_leg?) && !noanswer?
  end
  
  def ticket_notable?
    notable_type == "Helpdesk::Ticket"
  end
  
  
  def initialize_ticket(params)
    self.params = params
    self.customer_id = params[:custom_requester_id] if customer_id.blank?
    self.notable.attributes = {
      :account_id => account_id,
      :ticket_body_attributes => { :description_html => description_html(true) },
      :email => params[:requester_email],
      :name => requester_name,
      :phone => caller_number,
      :requester_id => params[:custom_requester_id] || customer_id,
      :responder => params[:agent],
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone],
      :subject => ticket_subject,
      :group => group
    }
    self.notable.build_ticket_and_sanitize
    self
  end
  
  def initialize_notes(params)
    self.params = params
    self.notable.attributes = {
      :account_id => account_id,
      :note_body_attributes => { :body_html =>  description_html(false) },
      :incoming => true,
      :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"],
      :user => params[:agent],
      :private => private_recording_note?
    }
    self.notable.build_note_and_sanitize
    self
  end
  
  def build_child_call(params)
    children.build(
      :call_type => call_type,
      :account_id => account_id,
      :freshfone_number_id => freshfone_number_id,
      :agent => params[:agent],
      :group_id => params[:group_id],
      :customer_id => child_call_customer_id(params),
      :params => params
    )
  end
  
  def direction_in_words
    incoming? ? CALL_DIRECTION_STR[:incoming] : CALL_DIRECTION_STR[:outgoing]
  end

  def notable_present?
    notable_id.present? && !included_notable.nil?
  end

  def associated_ticket
    # if notable is_a? 'Helpdesk::Note', notable.notable will return the ticket of that note
    ticket_notable? ? ticket : note.notable
  end

  def self.unbilled(from = 9.hours.ago, to = 3.hours.ago)
    find(:all, :conditions => 
      [ "call_cost IS NULL and call_status != ? and updated_at BETWEEN ? AND ?", 
        CALL_STATUS_HASH[:blocked], from, to ])
  end
  def self.calls_with_intermediate_status(from = 3.hours.ago, to = 1.hours.ago)
    find(:all, :conditions => 
      [ 'call_status IN (?) and updated_at > ? and updated_at < ?', 
    INTERMEDIATE_CALL_STATUS, from, to ])
  end

  def calculate_cost
    if parent.blank?
      calculator = Freshfone::CallCostCalculator.new({
        :call => id, 
        :call_sid => call_sid,
        :dial_call_sid => dial_call_sid 
      }, account)
      calculator.perform
    end
  end

  def conference
    account.freshfone_subaccount.conferences.get(conference_sid) if conference_sid
  end

  def conference?
    conference_sid.present?
  end

  def priority_queued_call?
    meta.agent_hunt? || meta.group_hunt?
  end

  def disconnect_source_agent
    agent_call_sid = agent_sid
    if outgoing?
      agent_call_sid = is_root? ? call_sid : dial_call_sid
    end
    agent_leg = account.freshfone_subaccount.calls.get(agent_call_sid)
    agent_leg.update(:status => "completed")  
  end

  def disconnect_agent
    #If this call is the parent and has any children, all children legs should be disconnected
    begin
      if has_children?
        child = children.last
        if child.present?
          Freshfone::NotificationWorker.perform_async(
            { :call_id => child.id }, nil,
            'complete_other_agents')
        end
        # return
      end
      if agent_sid
        agent_leg = account.freshfone_subaccount.calls.get(agent_sid)
        agent_leg.update(:status => "completed")  
      end
    rescue Exception => e
      Rails.logger.error "Unable to disconnect agent from the conference in #{account.id}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
    end
  end

  def disconnect_customer
    begin
      if customer_sid
        customer_leg = account.freshfone_subaccount.calls.get(customer_sid)
        customer_leg.update(:status => "completed")
      end
    rescue Exception => e
      Rails.logger.error "Unable to disconnect caller from the Conference in #{account.id}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
    end 
  end
    
  def cleanup_one_legged_call
    self.agent = nil
    self.call_status = Freshfone::Call::CALL_STATUS_HASH[:'no-answer']
    save
  end

  def dial_call_leg?(call_sid_param)
    return false if dial_call_sid.blank?
    call_sid_param == dial_call_sid
  end

  def transferred_leg?
    ancestry.present?
  end

  def round_robin_call?
    freshfone_number.round_robin?
  end

  def cleanup_and_disconnect_call
    cleanup_one_legged_call
    disconnect_agent
    disconnect_customer # Spreadheet L 6
  end

  def cleanup_outgoing_call
    disconnect_agent
    disconnect_customer
  end

  def add_to_hold_duration(duration)
    return if duration.blank? || duration == "0"
    hold_duration = 0 if hold_duration.blank?
    self.update_attributes!(:hold_duration => hold_duration + duration.to_i)
  end

  def set_total_duration(params)
    return if !account.features?(:freshfone_conference) || total_duration.present?
    self.total_duration = params[:CallDuration]
    self.total_duration = (Time.now.utc - created_at).to_i if incoming_root_call?
  end

  def set_call_duration(params)
    self.call_duration = params[:DialCallDuration] || params[:RecordingDuration] if self.call_duration.blank?
    self.call_duration = params[:CallDuration] if !freshfone_number.record? && self.call_duration.blank?
    set_total_duration(params)
  end

  def pulse_rate
    pulse_rate = Freshfone::PulseRate.new(self)
    return pulse_rate.missed_call_cost if (missed_or_busy? or failed?)
    return pulse_rate.voicemail_cost if voicemail?
    pulse_rate.pulse_charge
  end

  def missed_conf_transfer?
    (missed_or_busy? || failed?) && account.features?(:freshfone_conference) && parent.present?
  end

  def incoming_root_call?
    incoming? && is_root?
  end

  def missed_or_busy?
    busy? || noanswer? || canceled?
  end

  def sip?
    return false if meta.blank?
    meta.sip?
  end

  def create_sip_meta
    create_meta(:device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:sip])
  end

  def set_abandon_call(params)
    return if not_abandon_call?
    update_abandon_state(abandon_status) if (hangup_by_customer?(params) || hangup_in_ivr?(params))
  end

  def update_abandon_state(abandon_type)
    self.abandon_state = abandon_type
    save
  end

  def get_abandon_call_leg
    return self unless (has_children? && onhold?)
    child_call = children.last
    child_call.canceled? ?  self : child_call
  end

  private
    def called_agent(params)
      agent_scoper.find_by_id(params[:agent]) if 
        can_log_agent? && params[:agent].present? 
    end

    def child_call_customer_id(params)
      customer_id || (params[:customer] || {})[:id]
    end
    
    def country_name(country_code)
      return country_code if ["US", "USA"].include?(country_code)
      country = Carmen::Country.coded(country_code)
      country ? country.name : nil
    end

    def description_html(is_ticket)

      i18n_params = {
        :customer_name=> customer_name,
        :customer_number=> caller_number,
        :location => location,
        :freshfone_number => freshfone_number.number
      }
      if voicemail_ticket?
        i18n_label = "freshfone.ticket.voicemail_ticket_desc"
      elsif ivr_direct_dial?
        i18n_label = "freshfone.ticket.dial_a_number"
        i18n_params.merge!({:direct_dial_number => params[:direct_dial_number]})
      else
        i18n_label = "freshfone.ticket.ticket_desc"
        i18n_params.merge!({:agent => params[:agent].name,:agent_number => freshfone_number.number})
      end
      i18n_label += valid_customer_name? ? "_with_name" : "_with_out_name"
      desc = I18n.t(i18n_label, i18n_params)
      desc << "#{params[:call_log]}" unless is_ticket && private_recording_note?
      desc.html_safe
    end

    def valid_customer_name?
      customer_name.present? && (customer_name != caller_number)
    end

    def requester_name
       params_requester_name || caller_number
    end

    def ticket_subject
      return I18n.t('freshfone.ticket.voicemail_subject', 
              {:customer => customer_name || caller_number}) if voicemail_ticket?
      params_ticket_subject || default_ticket_subject
    end
    
    def voicemail_ticket?
      params[:voicemail]
    end
    
    def params_requester_name
      params[:requester_name] = caller_lookup(caller_number) if params[:requester_name].blank? || params[:requester_name] == caller_number
      params[:requester_name] 
    end
    
    def params_ticket_subject
      params[:ticket_subject] unless params[:ticket_subject].blank?
    end

    def default_ticket_subject
      I18n.t('freshfone.ticket.default_subject', 
        {:customer => customer_name || requester_name, 
         :call_date => formated_date(created_at)})
    end
    
    def ivr_direct_dial?
      params[:direct_dial_number].present?
    end

    def included_notable
      ticket_notable? ? ticket : note
    end

    def update_call_changes
      @call_model_changes = self.changes.clone
    end

    def trigger_recording_job?
      @call_model_changes.key?(:recording_url) && self.recording_audio.blank?
    end
    
    def recording_attachment_job
      record_params = {
        :account_id => account_id, 
        :call_sid => call_sid,
        :call_id => id,
        :call_duration => call_duration
      }
      record_params.merge!({:voicemail => true}) if ([ CALL_STATUS_HASH[:'no-answer'], CALL_STATUS_HASH[:voicemail]].include?(call_status))
      record_params.merge!({:agent => user_id}) if ( record_params[:voicemail] && !user_id.nil?)
      Resque::enqueue_at(30.seconds.from_now, Freshfone::Jobs::CallRecordingAttachment, record_params) if recording_url
    end

    def agent_scoper
      account.users.technicians.visible
    end

    def private_recording_note?
      freshfone_number.private_recording? && freshfone_number.record?
    end

    def build_recording_delete_params(user_id)
      {
        :recording_deleted => true,
        :recording_url => nil,
        :recording_deleted_info =>{
          :deleted_by => user_id,
          :deleted_at => Time.now.utc
        }
      }
    end

    def delete_twilio_recording(user_id)
      begin
        recording_sid = File.basename(self.recording_url)
        recording = account.freshfone_subaccount.recordings.get(recording_sid)
        recording.delete if recording.present?
      rescue Exception => e
        date = (Time.now.utc.ago 7.days)
        if self.updated_at >= date.beginning_of_day
          FreshfoneNotifier.call_recording_deletion_failure(
            :account_id => account.id,
            :call_id => self.id,
            :exception => e,
            :recording_url => recording_url,
            :user_id => user_id,
            :updated_at => updated_at)
        end
        Rails.logger.debug "Error deleting the recording from twilio for call id :#{self.id}, account id: #{account.id}, recording_sid: #{recording_sid}, User Id: #{user_id}.\n Message: #{e.message}"
      end
    end

    def transfer_call?(params)
      params[:transfer_call].present? || params[:external_transfer].present?
    end

  def not_abandon_call?
    outgoing? || voicemail? || !business_hour_call || abandon_state.present?
  end

  def hangup_by_customer?(params)
    (params[:CallStatus] == 'completed' && params[:DialCallStatus] == 'no-answer' )
  end

  def ivr_abandon?
    freshfone_number.ivr_enabled? && user_id.blank? && group_id.blank? && direct_dial_number.blank?
  end

  def abandon_status
    return Freshfone::Call::CALL_ABANDON_TYPE_HASH[:ivr_abandon] if ivr_abandon?
    Freshfone::Call::CALL_ABANDON_TYPE_HASH[:ringing_abandon]
  end

  def hangup_in_ivr?(params)
      return false if account.features?(:freshfone_conference)
      (params[:force_termination] &&  params[:CallStatus] == 'completed')
    end

end

class Freshfone::Telephony #Wrapper for all telephony provider related actions
  include Freshfone::FreshfoneUtil
  include Freshfone::Endpoints
  include Freshfone::NumberMethods
  include Freshfone::SubscriptionsUtil
  
  attr_accessor :params, :current_account, :current_number, :current_call, 
                :initiator, :routing_type, :provider

  def initialize(params={}, current_account=nil, current_number=nil, current_call = nil)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.current_call    = current_call
    #below: initializing Twilio directly now. inject the dependency when having multiple providers
    self.provider        = Freshfone::Providers::Twilio
  end

  def initiate_customer_conference(options={}, welcome_message=false)
    conf_params = conference_params(options, :customer)
    telephony(conf_params).initiate_conference(welcome_message)
  end

  def initiate_agent_conference(options={})
    conf_params = conference_params(options, :agent)
    telephony(conf_params).initiate_conference
  end

  def initiate_conference(options)
    telephony(conference_params(options)).initiate_conference
  end

  def join_conference(conf_params={})
    conf_params[:room] = room_name(conf_params[:sid], conf_params[:incoming_wait])
    telephony(conf_params).initiate_conference
  end

  def initiate_queue(type)
    telephony.enqueue(current_account.name, enqueue_url, quit_queue_url, type)
  end

  def initiate_voicemail(type="default")
    if current_number.voicemail_active
      telephony.voicemail(type, Freshfone::Call::VOICEMAIL_MAX_LENGTH, quit_voicemail_url)
    else
      provider.no_action
    end
  end

  def block_incoming_call
    telephony.block_incoming_call
  end

  def initiate_recording
    record_params = {
      :message             => 'Record your message at the tone.',
      :voice_type          => current_number.voice_type,
      :record_complete_url => record_message_url,
      :finishOnKey         => "#",
      :maxLength           => Freshfone::Call::RECORDING_MAX_LENGTH
    }
    telephony.record_settings_message record_params
  end

  def incoming_answered(agent)
    return no_action unless agent && agent.name
    telephony.call_answered_by(agent.name)
  end

  def return_non_availability(welcome_message=true)
    telephony.non_availability(current_number.voicemail_active, quit_voicemail_url, welcome_message)
  end
  alias_method :non_availability, :return_non_availability

  def return_non_business_hour_call
    telephony.non_business_hours(current_number.voicemail_active, quit_voicemail_url)
  end

  def hold_enqueue
    return telephony.add_to_hold_queue(params[:hold_queue], warm_transfer_wait_url,
                  warm_transfer_quit_url) if params[:transfer_type] == 'warm_transfer'
    telephony.add_to_hold_queue(params[:hold_queue], hold_wait_url, hold_quit_url)
  end

  def play_wait_music
    telephony.play_wait_music(current_number)
  end

  def play_agent_wait_music
    telephony.play_agent_wait_music
  end

  def play_hold_message
    telephony.play_hold_message(current_number)
  end

  def play_unhold_message
    telephony.play_unhold_message
  end

  def reject(reason=nil)
    telephony.reject reason
  end

  def incoming_missed
    telephony.incoming_missed
  end

  def no_action
    provider.no_action
  end

  def empty_twiml(message)
    telephony.empty_twiml(message)
  end

  def read_welcome_message(r)
    current_number.ivr.read_welcome_message(r)
  end

  def read_non_availability_message(r)
    current_number.read_non_availability_message(r)
  end

  def read_voicemail_message(r, type)
    current_number.read_voicemail_message(r, type)
  end

  def read_non_business_hours_message(r)
    current_number.read_non_business_hours_message(r)
  end

  def say_info(xml_builder, msg)
    telephony.say_twiml(xml_builder, msg)
  end

  def custom_forwarding_response(caller_name, url, voice_type)
    telephony.custom_forwarding_twiml(caller_name, url, voice_type)
  end

  def forward_invalid_option(url, caller_name, voice_type)
    telephony.forward_invalid_twiml(url, caller_name, voice_type)
  end

  #TwiML actions end here

  #REST Calls start here 

  def redirect_call_to_conference(caller_sid, hook)
    telephony.redirect_call(caller_sid, hook, current_account)
  end
  alias_method :redirect_call, :redirect_call_to_conference

  def initiate_outgoing
    outgoing_params = {
      :url             => outgoing_accept_url(current_call.id),
      :status_callback => outgoing_status_url(current_call.id,current_call.user_id), # SpreadsheetL 57,58,59
      :from            => current_number.freshfone_caller_id.blank? ? current_call.number : current_number.freshfone_caller_id.number, #Freshfone number
      :to              => current_call.caller_number,
      :timeLimit       => time_limit
    }
    dial_call = telephony.initiate_outgoing(current_account, outgoing_params)
    current_call.update_call({ :DialCallSid => dial_call.sid })
  end

  def make_call(call_params) #Merge with above method
    telephony.initiate_outgoing(current_account, call_params)
  end

  def initiate_hold(customer_sid, transfer_options=nil)
    transfer_options = prepare_transfer_options(transfer_options) unless transfer_options.blank?
    telephony.redirect_call(customer_sid, initiate_hold_url(customer_sid, transfer_options), current_account)
  end

  def initiate_unhold 
    customer_leg = outgoing_or_warm_transfer?(current_call) ? current_call.root.customer_sid : current_call.customer_sid
    telephony.dequeue(current_call.hold_queue, customer_leg,  unhold_url(current_call.id), current_account)
  end

  def initiate_transfer_on_unhold #Can be merged with intiate_unhold action
    params[:child_sid] = params[:CallSid] || current_call.children.last.dial_call_sid
    hold_queue = current_call.hold_queue || current_call.parent.hold_queue
    customer_leg = outgoing_or_warm_transfer?(current_call) ? current_call.root.customer_sid : current_call.customer_sid
    telephony.dequeue(hold_queue, customer_leg, transfer_on_unhold_url(current_call.id), current_account) 
  end

  def initiate_transfer_fall_back
    hold_queue = current_call.hold_queue || current_call.parent.hold_queue
    customer_leg = current_call.hold_leg_sid
    telephony.dequeue(hold_queue, customer_leg, transfer_fall_back_url(current_call.id), current_account)
  end

  def mute_participants
    conference = current_call.conference
    telephony.mute_participants(conference, customer_sid(current_call))
  end

  def unmute_participants
    conference = current_call.conference
    telephony.unmute_participants(conference)
  end

  def mute_supervisor(current_call, isMute)
    conference = current_call.conference
    telephony.mute_supervisor(conference, current_call.supervisor_controls.active.first.sid, isMute)
  end

  def disconnect_call(call_sid)
    telephony.disconnect_call(current_account, call_sid)
  end

  def call_ignored(params)
    telephony.call_ignored(params)
  end

  def call_status(call_sid)
    telephony.call_status(call_sid, current_account)
  end

  def redirect_call_to_voicemail(call)
    redirect_call call.call_sid, redirect_caller_to_voicemail(call.freshfone_number.id)
  end

  private
    def conference_params(options, actor = nil)
      options.merge!(default_moderation_params(actor)).merge!(options[:moderation_params] || {}) if actor.present?
      options[:room] = room_name(options[:sid], options[:incoming_wait])
      options[:timeLimit] ||= time_limit
      options[:recording_callback_url] = recording_call_back_url
      options[:record] ||= current_number.record? ? 'record-from-start' : 'do-not-record'
      options
    end

    def customer_conf_moderation_params
      { :beep => "onExit",
        :startConferenceOnEnter => false, :endConferenceOnExit => false }
    end

    def agent_conf_moderation_params
      { :beep => true,
        :startConferenceOnEnter => true, :endConferenceOnExit => true }
    end

    def customer_sid(call)
      outgoing_or_warm_transfer?(call) ? call.root.customer_sid : call.customer_sid
    end

    def default_moderation_params(actor)
      actor == :customer ? customer_conf_moderation_params : agent_conf_moderation_params
    end

    def time_limit
      ::Freshfone::Credit.call_time_limit(current_account, current_call)
    end

    def room_name(call_sid=nil, incoming_wait = false)
      sid  = call_sid || params[:CallSid]
      wait = incoming_wait == true ? "_wait" : ""
      "Room_#{current_account.id}_#{sid}#{wait}"
    end

    def prepare_transfer_options(transfer_options) #For hold
      params = "&call=#{transfer_options[:call]}"
      params << "&transfer=true&source=#{transfer_options[:source]}&target=#{transfer_options[:target]}&transfer_type=#{transfer_options[:transfer_type]}&group_transfer=#{transfer_options[:group_transfer]}#{external_transfer_params(transfer_options)}#{warm_transfer_params(transfer_options)}" if  transfer_options[:source].present?
      params
    end

    def external_transfer_params(transfer_options)
      return if transfer_options[:external_number].blank?
      "&external_transfer=true"
    end

    def warm_transfer_params(transfer_options)
      "&warm_transfer_call_id=#{transfer_options[:warm_transfer_call_id]}" if transfer_options[:transfer_type] == 'warm_transfer'
    end

    def telephony(params={})
      @telephony_provider = provider.new(params, self)
    end


end
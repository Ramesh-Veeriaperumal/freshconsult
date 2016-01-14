class Freshfone::Providers::Twilio

  TWILIO_ACTIVE_CALL_STATUS = ["queued", "ringing"]

  def initialize(conf_params={}, telephony)
    @room                   = conf_params[:room]
    @wait_url               = conf_params[:wait_url]
    @beep                   = conf_params[:beep]
    @time_limit             = conf_params[:timeLimit]
    @record                 = conf_params[:record]
    @startConferenceOnEnter = conf_params[:startConferenceOnEnter]
    @endConferenceOnExit    = conf_params[:endConferenceOnExit]
    @recording_url          = conf_params[:recording_callback_url]
    @available_agents       = conf_params[:available_agents]
    @telephony              = telephony
  end

  def self.no_action
    Twilio::TwiML::Response.new.text
  end

  def initiate_conference(welcome_message=false)
    twiml_response do |r|
      @telephony.read_welcome_message(r) if welcome_message
      comment_available_agents(r)
      r.Dial time_limit do |d|
        d.Conference @room, wait_url, recording_url,
          :beep => @beep,
          :record => @record,
          :startConferenceOnEnter => @startConferenceOnEnter, 
          :endConferenceOnExit => @endConferenceOnExit 
      end
    end
  end

  def enqueue(name, enqueue_url, quit_queue_url)
    twiml_response do |r|
      @telephony.read_welcome_message(r)
      r.Enqueue name, :waitUrl => enqueue_url, :action => quit_queue_url
    end
  end

  def non_availability(voicemail_active=false, quit_voicemail_url, welcome_message)
    twiml_response do |r|
      @telephony.read_welcome_message(r) if welcome_message
      @telephony.read_non_availability_message(r)
      if voicemail_active
        @telephony.read_voicemail_message(r, "default")
        r.Record :action => quit_voicemail_url, :finishOnKey => '#', :maxLength => Freshfone::Call::VOICEMAIL_MAX_LENGTH
      end
    end
  end

  def non_business_hours(voicemail_active=false, quit_voicemail_url)
    twiml_response do |r|
      @telephony.read_non_business_hours_message(r)
      if voicemail_active
        @telephony.read_voicemail_message(r, "default")
        r.Record :action => quit_voicemail_url, :finishOnKey => '#', :maxLength => Freshfone::Call::VOICEMAIL_MAX_LENGTH
      end
    end
  end

  def voicemail(type, max_length = Freshfone::Call::VOICEMAIL_MAX_LENGTH, quit_voicemail_url)
    twiml_response do |r|
      @telephony.read_voicemail_message(r, type)
      r.Record :action => quit_voicemail_url, :finishOnKey => '#', :maxLength => max_length
    end
  end

  def record_settings_message(options)
    twiml_response do |r|
      r.Say options[:message], :voice => options[:voice_type]
      r.Record :action => options[:record_complete_url], 
               :finishOnKey => options[:finishOnKey], :maxLength => options[:maxLength]
    end
  end

  def add_to_hold_queue(queue_name, wait_hook, quit_hook)
    twiml_response do |r|
      r.Enqueue queue_name, :waitUrl => wait_hook, :action => quit_hook
    end
  end

  def call_answered_by(name)
    twiml_response do |r|
      r.Say "Call answered by #{name}"
      r.Hangup
    end
  end

  def incoming_missed
    twiml_response do |r|
      r.Say "Call disconnected by the caller"
      r.Hangup
    end
  end

  def play_wait_music(number)
    twiml_response do |r|
      (number.wait_message.present? && number.wait_message.message_url.present?) ? 
        number.play_wait_message(r) : play_default_ringing_music(r)
    end
  end
  
  def play_default_music(xml_builder)
    xml_builder.Play Freshfone::Number::DEFAULT_WAIT_MUSIC, 
      :loop => 5
  end

  def play_hold_message(number)
    twiml_response do |r|
      (number.hold_message.present? && number.hold_message.message_url.present?)  ?
              number.play_hold_message(r) : play_default_music(r)
    end
  end

  def play_agent_wait_music
    twiml_response do |r|
      play_default_ringing_music(r)
    end
  end

  def play_default_ringing_music(xml_builder)
    xml_builder.Play Freshfone::Number::DEFAULT_RINGING_MUSIC,
      :loop => 50
  end

  def play_unhold_message
    twiml_response do |r|
      r.Play "http://com.twilio.music.guitars.s3.amazonaws.com/Pitx_-_A_Thought.mp3"
    end
  end

  def reject(reason)
    twiml_response do |r|
      r.comment! reason
      r.Reject
    end
  end

  def block_incoming_call
    twiml_response do |r|
      r.comment! "Call from a blacklisted number"
      r.Reject :reason => "busy"
    end
  end

  def empty_twiml(message)
    twiml_response do |r|
      r.comment! "#{message}"
    end
  end

  #TwiML actions end here

  #REST Calls start here 

  def initiate_outgoing(account, params)
    account.freshfone_subaccount.calls.create params
  end
  
  def redirect_call(sid, hook, account)
    call = account.freshfone_subaccount.calls.get(sid)
    call.update(:url => hook) # Need to handle if that api call was ended.
  end

  def mute_participants(conference)
    conference.participants.list.each do |participant|
      participant.update(:muted => true)
    end
  end

  def unmute_participants(conference)
    conference.participants.list.each do |participant|
      participant.update(:muted => false)
    end
  end

  def dequeue(queue_name, customer_leg, dequeue_url, account)
    queued_member = account.freshfone_subaccount.queues.get(queue_name).members.get(customer_leg)
    queued_member.dequeue(dequeue_url)
  end

  def disconnect_call(account,call_sid)
    agent_leg = account.freshfone_subaccount.calls.get(call_sid)
    agent_leg.update(:status => "completed") if TWILIO_ACTIVE_CALL_STATUS.include?(agent_leg.status)
  end

  def call_ignored(params)
    twiml = Twilio::TwiML::Response.new do |r|
      r.Comment "Agent #{params[:agent_id]} ignored the forwarded call"
      r.Hangup #hanging up this particular call. other calls should still be ringing. test this scenarion thoroughly
    end
    twiml.text
  end

  def call_status(sid, account)
    call = account.freshfone_subaccount.calls.get(sid)
    call.present? ? call.status : nil
  end

  private
    def twiml_response
      twiml = Twilio::TwiML::Response.new do |r|
        yield r
      end
      twiml.text
    end

    def wait_url
      { :waitUrl => @wait_url } unless @wait_url.nil?
    end

    def time_limit
      { :timeLimit => @time_limit } unless @time_limit.nil?
    end

    def recording_url
      { :eventCallbackUrl => @recording_url } unless @recording_url.nil? 
    end

    def comment_available_agents(xml_builder)
      return if @available_agents.blank?
      xml_builder.comment! "Calling Agent(s) whose User Details and Device they are in are mentioned below:"
      @available_agents.each_with_index do |agent, index|
        xml_builder.comment! "#{index+1}) User Id :: #{agent[:id]},  Name :: #{agent[:name]},  Device :: #{agent[:device_type].to_s}"
      end
    end

end
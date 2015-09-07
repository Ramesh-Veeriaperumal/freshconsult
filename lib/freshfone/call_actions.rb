class Freshfone::CallActions
  include Freshfone::NodeNotifier
  include Freshfone::NodeEvents

	attr_accessor :params, :current_account, :current_number, :agent, :outgoing
	
	def initialize(params={}, current_account=nil, current_number=nil)
		self.params          = params
		self.current_account = current_account
		self.current_number  = current_number
	end

	def register_incoming_call
		current_account.freshfone_calls.create(
			:freshfone_number => current_number,
			:customer => search_customer_with_number(params[:From]),
			:call_type => Freshfone::Call::CALL_TYPE_HASH[:incoming],
			:business_hour_call => working_hours?,
			:params => params
		)
	end

	def register_blocked_call
		current_account.freshfone_calls.create(
			:freshfone_number => current_number,
			:customer => search_customer_with_number(params[:From]),
			:call_type => Freshfone::Call::CALL_TYPE_HASH[:incoming],
			:call_status => Freshfone::Call::CALL_STATUS_HASH[:blocked],
			:business_hour_call => working_hours?,
			:params => params
		)
	end

	def register_outgoing_call
		current_account.freshfone_calls.create(
			:freshfone_number => current_number,
			:agent => calling_agent,
			:customer => search_customer_with_number(called_number),
			:call_type => Freshfone::Call::CALL_TYPE_HASH[:outgoing],
			:business_hour_call => working_hours?,
			:params => params
		)
	end

	def update_agent_leg(call)
		call.agent = current_account.users.technicians.visible.find(params[:agent_id] || params[:agent]) if call.user_id.blank?
		call.dial_call_sid = params[:CallSid]
		call.call_status = Freshfone::Call::CALL_STATUS_HASH[:'in-progress']
		call.call_type = Freshfone::Call::CALL_TYPE_HASH[:incoming]
		call.save
	end

	def update_customer_leg(call) #Can be merged with the method above
		call.update_attributes(
			:call_status => Freshfone::Call::CALL_STATUS_HASH[:'in-progress'],
			:dial_call_sid => params[:CallSid],
			:call_type => Freshfone::Call::CALL_TYPE_HASH[:outgoing]
		)
	end

	def register_direct_dial(number)
		call = current_account.freshfone_calls.find_by_call_sid(params[:CallSid])
		if call
			call.direct_dial_number = number
			call.save
		end
	end
	
	def register_call_transfer(agent, outgoing = false)
		self.outgoing = outgoing
		params.merge!({:agent => calling_agent(agent)})
		return if current_call.blank?
		set_call_sid_to_parent if outgoing
		current_call.root.increment(:children_count).save if build_child.save
	end

	def register_group_call_transfer(outgoing = false)
    self.outgoing = outgoing
    return if current_call.blank?
		set_call_sid_to_parent if outgoing
    current_call.root.increment(:children_count).save if build_child.save
  end

  def register_external_transfer(outgoing = false)
  	self.outgoing = outgoing
  	return if current_call.blank?
		set_call_sid_to_parent if outgoing
  	current_call.root.increment(:children_count).save if build_child.save
  end

	def save_call_meta(group)
		current_call.group_id = group
		current_call.save
	end

	def save_conference_meta(type, performer = nil,  transfer_by_agent = nil)
		current_call.group_id = performer if type == :group
		current_call.user_id  = performer if type == :agent
		return external_call_meta(performer,transfer_by_agent) if type == :number
		target_group = (type == :group) ? performer : nil
		current_call.create_meta(
			:account       => current_account, 
			:hunt_type     => Freshfone::CallMeta::HUNT_TYPE[type],
			:transfer_by_agent => transfer_by_agent,
			:pinged_agents => pinged_agents(performer,type) || load_target_agents(target_group) )
		current_call.save
		trigger_notification_validator(current_call.id)
	end

	def external_call_meta(performer, transfer_by_agent)
		current_call.direct_dial_number = performer
		current_call.create_meta(:account => current_account,
		:hunt_type => Freshfone::CallMeta::HUNT_TYPE[:number],
		:meta_info => performer, 
		:transfer_by_agent => transfer_by_agent,
		:device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
		:pinged_agents => [ { :number => performer, :device_type => :external} ])
		trigger_notification_validator(current_call.id)
	end

	def set_status_restricted
    return if params[:CallSid].blank?
    current_call.update_status({:DialCallStatus => "restricted"}).save
  end

  def update_agent_leg_response(agent_id, response, call)
  	call.meta.update_pinged_agents_with_response(agent_id, response) 
  end

  def update_external_transfer_leg_response(number, response, call)
  	call.meta.update_external_transfer_call_response(number, response) 
  end

  def handle_failed_mobile_incoming_call(call, agent_id)
    call_meta = call.meta
    return if call_meta.blank?
    call_meta.update_pinged_agents_with_response(agent_id, :failed)
    telephony.redirect_call_to_voicemail call if call_meta.all_agents_missed?
  end

  def handle_failed_direct_dial_call(call)
    call.meta ||= current_account.freshfone_calls.find(call.id).create_meta(
      :meta_info => call.direct_dial_number, :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:direct_dial])
    call.failed!
    telephony.redirect_call_to_voicemail call
  end

  def handle_failed_mobile_transfer_call(call, agent_id)
    child_call = call.children.last
    child_call_meta = child_call.meta
    return if child_call_meta.blank?
    child_call_meta.update_pinged_agents_with_response(agent_id, :failed)
    if child_call_meta.all_agents_missed?
      child_call.failed!
      notify_transfer_unanswered call
    end
  end

  def handle_failed_external_transfer_call(call)
    child_call = call.children.last
    child_call_meta = child_call.meta
    child_call_meta.update_external_transfer_call_response(params[:external_number], :failed) if child_call_meta.present?
    child_call.update_call({:direct_dial_number => "+#{params[:external_number]}", :DialCallStatus => 'failed'})
    notify_transfer_unanswered call
  end

	private

		def pinged_agents(performer, type)
			return if (type != :agent)
			agent = current_account.freshfone_users.find_by_user_id(performer)
			return if agent.blank? #Can happen if IVR redirects to an agent who has no associated freshfone_user entry
			[agent_hash(agent)] 
		end

		def load_target_agents(group=nil)
			available_agents = current_account.freshfone_users.load_agents(current_number, group)[:available_agents]
			available_agents.inject([]) do |agents, freshfone_user|
	      agents << agent_hash(freshfone_user)
	    end
		end

		def agent_hash(freshfone_user)
		 { :id => freshfone_user.user_id, 
		 	 :ff_user_id => freshfone_user.id,
	     :name => freshfone_user.name,
	     :device_type => freshfone_user.available_on_phone? ? :mobile : :browser 
	   }
		end


		def calling_agent(agent = params[:agent])
			current_account.users.technicians.visible.find_by_id(agent)
		end
		
		def build_child
			call = current_call.has_children? ? get_child_call : current_call
			direction = call.direction_in_words
			if call.customer_id.blank?
				params[:customer] = search_customer_with_number(params["#{direction}"])
			end
			Rails.logger.debug "Child Call Id:: #{current_call.id} :: Group_id::  #{current_call.group_id} :: params :: #{params[:group_id]}"
			params[:group_id] ||= call.group_id unless call.group_id.blank?
			call.build_child_call(params)
		end

		def get_child_call
			call = current_call.children.last
			return call unless current_account.features?(:freshfone_conference)
			(call.busy? || call.noanswer? ||  call.canceled?|| call.ringing?) ? call.parent : call
		end
		
		def current_call # Internal parameters have been changed to plain `call` because of potential conflict with this method
			if params[:call]
				@current_call ||= current_account.freshfone_calls.find(params[:call]) #Use the one in Freshfone::CallHistory
			else
			  @current_call ||= current_account.find_by_call_sid(call_sid)
			end
		end
		
		def called_number
			params[:PhoneNumber] || params[:To]
		end
		
		def call_sid
			return params[:CallSid] if current_account.features?(:freshfone_conference)
			outgoing ? params[:ParentCallSid] : params[:CallSid]
		end
		
		def search_customer_with_number(phone_number)
			# Freshfone::Search.search_user_with_number(phone_number)
			users_scoper.find_by_phone(phone_number) || users_scoper.find_by_mobile(phone_number)
		end

		def users_scoper
			current_account.users
		end

		def working_hours?
      current_number.present? && (current_number.non_business_hour_calls? or within_business_hours?)
    end

    def within_business_hours?
		   default_business_calendar = current_number.business_calendar 
		   default_business_calendar.blank? ? (default_business_calendar = Freshfone::Number.default_business_calendar(current_number)) :
		        (Time.zone = default_business_calendar.time_zone)  
		   business_hours = Time.working_hours?(Time.zone.now,default_business_calendar)
		  ensure
		    TimeZone.set_time_zone
    end

    def telephony
      @telephony ||= Freshfone::Telephony.new params, current_account, current_number
    end

    def trigger_notification_validator(call_id)
    	Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::NotificationMonitor, 
    			{:account_id => current_account.id, :freshfone_call => call_id}) if current_call.present?
    end

    #Method to set the call sid to parent call sid for outgoing calls.
    #For incoming we already store in this form. Hence replicating the same for outgoing too.
    def set_call_sid_to_parent
      params.merge!({:CallSid => current_call.call_sid}) if current_account.features?(:freshfone_conference)
    end

end
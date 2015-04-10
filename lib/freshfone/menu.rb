require 'tree'
class Freshfone::Menu < Tree::TreeNode
	include Freshfone::MessageMethods
  attr_accessor :message, :message_type, :menu_options, :menu_id, :ivr, :name,
								:attachment_id, :parent, :children_hash, :children, :content,
								:recording_url, :menu_name, :params
	@@blacklist_attributes = [:menu_options, :ivr, :options, :avatar, :attachments,
														:children, :children_hash].map{|v| "@#{v}".to_sym }
	delegate :account, :has_new_attachment?, :find_menu, :perform_call, :attachments,
					 :voice_type, :freshfone_number_id, :to => :ivr

	# name is used as unique identifier by rubyTree and so name is set value of menu_id
  def initialize(menu)
    menu.each_pair do |k,v|
      instance_variable_set('@' + k.to_s, v)
    end
		options
	end

	def options_hash
		@options_hash ||= options.inject({}) { |options_hash, option|
			options_hash[option.respond_to_key] = option
			options_hash }
	end
	
	def parent_menu
		parent || self
	end
  
  def options
    @options ||= begin
      (menu_options || {}).map { |k, v| create_option(v) }.sort_by { |o| o.respond_to_key }
    end
  end
  
  # to avoid printing of @menu_options and @ivr
  def inspect
    @@blacklist_attributes = []
    return super.inspect if @@blacklist_attributes.blank?
    vars = instance_variables.reject{|v| 
            @@blacklist_attributes.include? v }.map{|v| 
              "#{v}=#{instance_variable_get(v).inspect}"}.join(", ") 

		"<#{self.class}::0x#{self.object_id.to_s(16)} #{vars}>"
  end
	
	def validate
		ivr.errors.add(:base,"Cannot have blank message for menu '#{menu_name}'") unless has_message?
		ivr.errors.add(:base,"Message shouldn't exceed 4096 characters for menu '#{menu_name}'") if has_invalid_size?
		ivr.errors.add(:base,"Atleast one keypress option need for '#{menu_name}'") if  ( !has_options? && ivr.ivr_message?)
		validate_options
	end
	
	def to_yaml_properties
		#options should be serialized before children and children hash to prevent 
		#yaml dump from creating the child menu refrence first. 
		#Only this allows the root menu to have an id of id001.
		instance_variables.reject{|v| [:@menu_options, :@options, :@ivr].include? v }.prepend(:@options)
	end
		
	def as_json(options=nil)
		{ :message => message,
			:messageType => message_type,
			:menuName => CGI.escapeHTML(menu_name),
			:menuId => menu_id,
			:attachmentId => attachment_id,
			:attachmentName => attachment_name,
			:attachmentUrl => attachment_url,
			:recordingUrl => recording_url,
			:options => self.options
		}
	end
  
  def to_json(options=nil)
    hash = as_json
    hash[:options] = as_json(options)[:options].to_json
    hash.to_json
  end

	def speak(params={}, options={ :preview_alert => false, :invalid => false })
		self.params ||= params
		twiml = Twilio::TwiML::Response.new do |r|
			say_verb(r, "Please enter a valid option.") if options[:invalid]
			preview_alert_message(r) if options[:preview_alert]
			has_options? ? menu_gather(r) : ivr_message(r)
			r.Redirect "#{status_url}?force_termination=true&preview=#{preview?}&number_id=#{freshfone_number_id}", :method => "POST"
		end
		[:twiml, twiml.text]
	end
	
	def handle_menu_jumps(option)
		# use current_option
		(option.jump_to? ? find_menu(option.performer_id) : parent_menu).speak(params)
	end
	
	def perform_action(params={})
		self.params = params
		(no_option? || first_time_entry?) ? invalid_selction_or_root : current_option.perform_action
	end
	
	def ivr_message(xml_builder)
		if transcript?
			say_verb(xml_builder, message)
		else
			xml_builder.Play(uploaded_audio? ? attachment_url : recording_url)
		end
	end
	
	private
		def preview_alert_message(xml_builder)
			say_verb(xml_builder, "Cannot make calls in preview mode.")
		end
	
		def say_verb(xml_builder, msg)
			xml_builder.Say msg, { :voice => voice_type }
		end
		
		def menu_gather(xml_builder)
			xml_builder.Gather :action => action_url, :timeout => 60, :numDigits => 1,  :finishOnKey => "" do |g|
				ivr_message(g)
				g.Pause :length => '5'
				ivr_message(g)
				g.Pause :length => '5'
				ivr_message(g)
			end
		end

		def action_url
			preview? ? preview_url : live_ivr_url
		end

		def preview_url
			"#{host}/freshfone/preview_ivr/#{ivr.id}?preview=true&menu_id=#{menu_id}"
		end

		def live_ivr_url
			"#{host}/freshfone/ivr_flow?menu_id=#{menu_id}"
		end

		def invalid_selection?
			no_option? && !first_time_entry?
		end
		
		def no_option?
			current_option.blank? # &&!is_root?
		end

		def first_time_entry?
			params[:Digits].blank?
		end
		
		def preview?
			params[:preview] || false
		end
		
		def current_option
			@current_option ||= options_hash[params[:Digits]]
		end
		
		def invalid_selction_or_root
			speak(params, { :invalid => invalid_selection? })
		end
		
		def host
			account.url_protocol + "://" + account.full_domain
		end

		def has_options?
			!options.blank?
		end

		def validate_options
			options.each { |option| option.validate }
		end
		
		def create_option(option)
			Freshfone::Option.new({ :performer => option["performer"].to_sym,
				:performer_id => option["performer_id"].blank? ? nil : option["performer_id"].to_i, 
				:respond_to_key => option["respond_to_key"],
				:performer_number => option["performer_number"],
				:menu => self })
		end
		
		def new_attachment_reference
			menu_id
		end

		def status_url
			"#{host}/freshfone/call/status"
		end
end
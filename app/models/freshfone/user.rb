class Freshfone::User < ActiveRecord::Base
	set_table_name "freshfone_users"
	belongs_to_account

	belongs_to :user, :inverse_of => :freshfone_user
	has_many :agent_groups, :through => :user
	delegate :available_number, :name, :avatar, :to => :user
	attr_accessor :user_avatar

	attr_protected :account_id

	PRESENCE = {
		:offline => 0,
		:online => 1,
		:busy => 2
	}

	INCOMING = {
		:not_allowed => 0,
		:allowed => 1
	}

	validates_presence_of :user, :account
	validates_inclusion_of :presence, :in => PRESENCE.values,
		:message => "%{value} is not a valid presence"
	validates_inclusion_of :incoming_preference, :in => INCOMING.values,
		:message => "%{value} is not a valid incoming preference"

	named_scope :online_agents, :conditions => { :presence => PRESENCE[:online] }, :include => :user
	named_scope :raw_online_agents, :conditions => { :presence => PRESENCE[:online] }
	named_scope :online_agents_with_avatar,
							:conditions => { :presence => PRESENCE[:online] },
							:include => [:user => [:avatar]]
	named_scope :busy_agents, :conditions => { :presence => PRESENCE[:busy] }
	named_scope :agents_in_group, lambda { |group_id|
		{:joins => "INNER JOIN agent_groups ON agent_groups.user_id = #{table_name}.user_id AND
								agent_groups.account_id = #{table_name}.account_id",
		 :conditions => ["agent_groups.group_id = ? ", group_id]
		}
	}

	def set_presence(status)
		self.presence = status
		save
	end
	
	def reset_presence
		self.presence = incoming_preference
		self
	end
	
	def change_presence_and_preference(status, user_avatar_content)
		self.user_avatar = user_avatar_content
		self.incoming_preference = status
		self.presence = status if !busy?
	end
	
	PRESENCE.each_pair do |k, v|
		define_method("#{k}?") do
			presence == v
		end
	end
	
	INCOMING.each_pair do |k, v|
		define_method("incoming_#{k}?") do
			presence == v
		end
	end

	def self.online_agents_in_group(group_id)
		online_agents.agents_in_group(group_id)
	end
	
	def self.busy_agents_in_group(group_id)
		busy_agents.agents_in_group(group_id)
	end
	
	def number
		@number ||= available_number
	end

	def call_agent_twiml(xml_builder, forward_call_url, current_number)
		available_on_phone? && vaild_phone_number?(current_number) ? call_agent_on_phone(xml_builder, forward_call_url) :
													call_agent_on_browser(xml_builder)
	end
	
	private

		def call_agent_on_phone(xml_builder, forward_call_url)
			@agent_number = GlobalPhone.parse(number).international_string
			xml_builder.Number @agent_number, :url => forward_call_url
		end
		
		def call_agent_on_browser(xml_builder)
			xml_builder.Client user_id
		end
		
		def vaild_phone_number?(current_number)
			@current_number = current_number.number
			@agent_number = GlobalPhone.parse(number)
			@agent_number && @agent_number.valid? && can_dial_agent_number?
		end

		def can_dial_agent_number?
			@agent_number.national_string != GlobalPhone.parse(@current_number).national_string
		end

end

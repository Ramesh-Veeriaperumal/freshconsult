class Freshfone::User < ActiveRecord::Base
	self.table_name =  "freshfone_users"
	belongs_to_account

	belongs_to :user, :class_name => '::User', :inverse_of => :freshfone_user
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

	scope :online_agents, lambda { {:conditions => [ "freshfone_users.presence = ? or (freshfone_users.presence = ? and freshfone_users.mobile_token_refreshed_at > ?)", PRESENCE[:online], PRESENCE[:offline], 1.hour.ago], :include => :user }}
	scope :raw_online_agents, lambda { {:conditions => [ "freshfone_users.presence = ? or (freshfone_users.presence = ? and freshfone_users.mobile_token_refreshed_at > ?)", PRESENCE[:online], PRESENCE[:offline], 1.hour.ago] }}
	scope :online_agents_with_avatar, lambda { {
							:conditions => [ "freshfone_users.presence = ? or (freshfone_users.presence = ? and freshfone_users.mobile_token_refreshed_at > ?)", PRESENCE[:online], PRESENCE[:offline], 1.hour.ago],
							:include => [:user => [:avatar]] }}
	scope :busy_agents, :conditions => { :presence => PRESENCE[:busy] }
	scope :agents_in_group, lambda { |group_id|
		{:joins => "INNER JOIN agent_groups ON agent_groups.user_id = #{table_name}.user_id AND
								agent_groups.account_id = #{table_name}.account_id",
		 :conditions => ["agent_groups.group_id = ? ", group_id]
		}
	}

	named_scope :agents_by_last_call_at, lambda { |order_type| order_type = "ASC" if order_type.blank?
		{:conditions => [ "freshfone_users.presence = ? or (freshfone_users.presence = ? and freshfone_users.mobile_token_refreshed_at > ?)", 
		PRESENCE[:online], PRESENCE[:offline], 1.hour.ago], :include => :user, :order => "freshfone_users.last_call_at #{order_type}" } }

	def set_presence(status)
		self.presence = status
		save
	end
	
	def reset_presence
		self.presence = incoming_preference
		self
	end
	
	def change_presence_and_preference(status, user_avatar_content, nmobile = false)
		self.user_avatar = user_avatar_content
		if nmobile
			self.mobile_token_refreshed_at = Time.now if self.incoming_preference == INCOMING[:allowed]
		else
			self.incoming_preference = status
			self.presence = status unless busy?
			self.mobile_token_refreshed_at = 2.hours.ago if self.incoming_preference == INCOMING[:not_allowed] && self.mobile_token_refreshed_at.present?
		end
	end
	
	PRESENCE.each_pair do |k, v|
		define_method("#{k}?") do
			if k.eql? :online
				presence == v || (presence == PRESENCE[:offline] && mobile_token_refreshed_at.present? && mobile_token_refreshed_at > 1.hour.ago)
			else
				presence == v
			end
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

	def call_agent_twiml(xml_builder, forward_url, current_number, presence_update_url)
		available_on_phone? && vaild_phone_number?(current_number) ? call_agent_on_phone(xml_builder, forward_url) :
													call_agent_on_browser(xml_builder, presence_update_url)
	end
	

	def set_last_call_at(last_call_time)
		self.last_call_at = last_call_time
		save
	end

	private

		def call_agent_on_phone(xml_builder, forward_call_url)
			@agent_number = GlobalPhone.parse(number).international_string
			xml_builder.Number @agent_number, :url => forward_call_url
		end
		
		def call_agent_on_browser(xml_builder, presence_update_url)
			xml_builder.Client user_id, :url => presence_update_url
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

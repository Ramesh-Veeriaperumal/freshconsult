class Freshfone::Ivr < ActiveRecord::Base
  self.primary_key = :id
	self.table_name =  "freshfone_ivrs"
	require_dependency 'freshfone/menu'
	require_dependency 'freshfone/option'
	require_dependency 'freshfone/number/message'

	serialize :ivr_data, Hash
	serialize :ivr_draft_data, Hash
	serialize :welcome_message

	has_many :attachments, :as => :attachable, :class_name => 'Helpdesk::Attachment', 
						:dependent => :destroy
	
	validate :validate_menus, :validate_attachments, :validate_welcome_message
	belongs_to_account
	belongs_to :freshfone_number, :class_name => 'Freshfone::Number'
	delegate :voice_type, :to => :freshfone_number
	delegate :group_id, :group, :to => :welcome_message, :allow_nil => true
	delegate :attachment_id, :to => :welcome_message, :allow_nil => true, :prefix => true

	attr_protected :account_id
	attr_accessor :relations, :attachments_hash, :params, :preview_mode, :menus_list
  after_find :assign_ivr_to_welcome_message
  after_create :assign_ivr_to_welcome_message
  
	# Format: [symbol, twilio_type, display_name, value_for_select_tag]

	validates_presence_of :account_id, :freshfone_number_id
	
	MESSAGE_TYPE = [
		[ :simple, 'Simple', 0 ],
		[ :ivr,	'ivr',	1 ],
	]

	MESSAGE_TYPE_HASH = Hash[*MESSAGE_TYPE.map { |i| [i[0], i[2]] }.flatten]
	
	MESSAGE_TYPE_HASH.each_pair do |k, v|
		define_method("#{k}_message?") do
			message_type == v
		end
	end
	
	def menus
		self.menus_list ||= begin
			get_menus(get_ivr_data)
		end
	end

	def all_menus
		@all_menus ||= begin
			get_menus(ivr_data) + get_menus(ivr_draft_data)
		end
	end

	def menus_hash
		@menus_hash ||= menus.inject({}) { |menus_hash, menu|
			menus_hash[menu.menu_id] = menu
			menus_hash }
	end
	
	def set_preview_mode
		self.preview_mode = true
		self
	end

	def has_new_attachment?(menu_id)
		attachments_hash.has_key?(menu_id.to_s)
	end
	
	def find_menu(menu_id)
		menus_hash[menu_id]
	end
	
	def perform_action(params={})
		self.params = params
		set_preview_mode if params[:preview] && params[:preview].to_bool
		# empty_twiml = Twilio::TwiML::Response.new
		current_menu.perform_action(params)
	end

	def unused_attachments
		inuse_attachment_ids = (all_menus.collect(&:attachment_id) << welcome_message_attachment_id ).compact
		attachments.reject{ |a| inuse_attachment_ids.include? a.id }
	end

	def any_ivr_data_changed?
		ivr_data_changed? || ivr_draft_data_changed?
	end

	def get_ivr_data
		preview_mode && self.ivr_draft_data.present? ? self.ivr_draft_data : self.ivr_data
	end
	
	def read_welcome_message(xml_builder)
		welcome_message.speak(xml_builder) if welcome_message.present? && simple_message?
	end

	private

		def validate_menus 
			menus.each { |menu| menu.ivr = self; menu.validate } if ivr_message? || preview_mode
		end
		
		def validate_welcome_message
			welcome_message.validate if welcome_message? && !preview_mode
		end
		
		def validate_attachments
			(attachments || []).each do |a|
				if a.id.blank? 
					errors.add(:base,I18n.t('freshfone.admin.invalid_attachment',
						{ :name => a.content_file_name })) unless a.mp3?  
				end
			end
		end

		# Actions
		
		# First menu is considered to be menu 0
		def current_menu
			@current_menu ||= menus_hash[(params[:menu_id]).to_i] || menus.first.root
		end

		def perform_call(menu, performer, performer_id)
			return menu.speak(params, { :preview_alert => true }) if params[:preview]
			[performer, performer_id]
		end

		def get_menus(ivr_data)
			(ivr_data || {}).map do |k, v|
				v.ivr = self
				v
			end.sort_by { |m| m.menu_id }
		end
		
		def assign_ivr_to_welcome_message
			self.welcome_message.parent = self unless welcome_message.blank?
		end

end

class Helpdesk::NoteBody < ActiveRecord::Base

	set_table_name "helpdesk_note_bodies"
	belongs_to_account
	belongs_to :note, :class_name => 'Helpdesk::Note', :foreign_key => 'note_id'
	attr_protected :account_id
	unhtml_it :body, :full_text
	xss_sanitize :only => [:body_html,:full_text_html],  :html_sanitize => [:body_html,:full_text_html]	
	before_save :load_full_text


	def load_full_text	
		self.full_text ||= body unless body.blank? 
		self.full_text_html ||= body_html unless body_html.blank?
	end
	
end
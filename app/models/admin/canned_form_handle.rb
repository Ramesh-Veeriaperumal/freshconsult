class Admin::CannedFormHandle < ActiveRecord::Base
  self.primary_key = :id
  belongs_to_account

  attr_accessible :id_token, :ticket_id, :response_note_id, :response_data

  belongs_to :canned_form, class_name: 'Admin::CannedForm'
  belongs_to :ticket, class_name: 'Helpdesk::Ticket'
  belongs_to :response_note, class_name: 'Helpdesk::Note'

  serialize :response_data, Hash

  before_create :generate_secret

  def generate_secret
    self.id_token = Digest::MD5.hexdigest(Helpdesk::SECRET_1 + canned_form.id.to_s + ticket.id.to_s + Time.now.to_f.to_s).downcase
  end

  def handle_url
    Rails.application.routes.url_helpers.support_canned_forms_response_url(id_token, host: self.ticket.portal_host)
  end

  def support_ticket_url
    Rails.application.routes.url_helpers.support_ticket_url(self.ticket.display_id, host: self.ticket.portal_host)
  end
end

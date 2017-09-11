class Freshcaller::Call < ActiveRecord::Base
  self.table_name =  :freshcaller_calls
  self.primary_key = :id
  
  belongs_to_account
  
  belongs_to :ticket, :foreign_key => 'notable_id', :class_name => 'Helpdesk::Ticket'
  belongs_to :note, :foreign_key => 'notable_id', :class_name => 'Helpdesk::Note'
  
  belongs_to :notable, :polymorphic => true, :validate => true

  validates :fc_call_id, uniqueness: true

  def ticket_id
    return if notable_id.blank?
    return notable_id if notable_type.eql?('Helpdesk::Ticket')
    notable.notable.display_id
  end

  def note_id
    notable_id if notable_id.present? && notable_type.eql?('Helpdesk::Note')
  end
end

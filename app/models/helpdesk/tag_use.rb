class Helpdesk::TagUse < ActiveRecord::Base
  set_table_name "helpdesk_tag_uses"

  belongs_to :tags, 
    :class_name => 'Helpdesk::Tag',
    :foreign_key => 'tag_id',
    :counter_cache => true

  belongs_to :tickets, 
    :class_name => 'Helpdesk::Ticket',
    :foreign_key => 'ticket_id'

  validates_uniqueness_of :tag_id, :scope => :ticket_id
  validates_numericality_of :tag_id, :ticket_id
  
end

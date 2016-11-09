class Helpdesk::ParentChildTemplate < ActiveRecord::Base

  belongs_to_account
  belongs_to :parent_template,
	  :class_name => 'Helpdesk::TicketTemplate'
  belongs_to :child_template,
	  :class_name => 'Helpdesk::TicketTemplate'
end
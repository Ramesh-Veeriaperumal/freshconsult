class Company < ActiveRecord::Base
  
  belongs_to_account
  
  has_custom_fields :class_name => 'CompanyFieldData', :discard_blank => false # coz of schema_less_company_columns
  
  has_many :users , :class_name =>'User' ,:conditions =>{:deleted =>false} , :dependent => :nullify,
           :order => :name, :foreign_key => 'customer_id'
  
  has_many :all_users , :class_name =>'User' , :dependent => :nullify , :order => :name,
           :foreign_key => 'customer_id'

  has_many :all_tickets ,:class_name => 'Helpdesk::Ticket', :through => :all_users , 
           :source => :tickets

  has_many :customer_folders, :class_name => 'Solution::CustomerFolder', :dependent => :destroy,
           :foreign_key => 'customer_id'
           
  has_many :tickets , :through =>:users , :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id"
  
  has_many :archive_tickets , :through => :all_users , :class_name => 'Helpdesk::ArchiveTicket'

end
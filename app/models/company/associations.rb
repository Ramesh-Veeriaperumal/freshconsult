class Company < ActiveRecord::Base
  
  belongs_to_account
  
  has_custom_fields :class_name => 'CompanyFieldData', :discard_blank => false # coz of schema_less_company_columns

  has_many :user_companies, :class_name => 'UserCompany'
  
  has_many :users, :class_name =>'User', :through => :user_companies, :order => :name, 
                    :foreign_key => 'company_id', :conditions => {:deleted =>false}
  
  has_many :all_users, :through => :user_companies, :source => :user, :order => :name,
                        :foreign_key => 'company_id'

  has_many :all_tickets ,:class_name => 'Helpdesk::Ticket', :foreign_key => "owner_id"

  has_many :customer_folders, :class_name => 'Solution::CustomerFolder', :dependent => :destroy,
           :foreign_key => 'customer_id'
  
  has_many :archive_tickets , :class_name => 'Helpdesk::ArchiveTicket' , :foreign_key => "owner_id"

  has_many :company_domains, :dependent => :destroy

  accepts_nested_attributes_for :company_domains, :allow_destroy => true

end

class Admin::DataImport < ActiveRecord::Base
  
  set_table_name "admin_data_imports"    
  
  belongs_to :account
  
  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
    
end

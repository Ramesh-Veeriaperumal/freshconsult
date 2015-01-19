class Admin::DataImport < ActiveRecord::Base

	include Import::Zen::Redis

	after_destroy :clear_key, :if => :zendesk_import?
  
  set_table_name "admin_data_imports"    
  
  belongs_to :account
  
  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
    
  IMPORT_TYPE = {:zendesk => 1, :contact => 2, :company => 3}
  ZEN_IMPORT_STATUS = { :started => 1 , :completed => 2 }

  private

	  def clear_key
	  	clear_redis_key
	  end

	  def zendesk_import?
	  	source == IMPORT_TYPE[:zendesk]
	  end

end

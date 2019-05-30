class Social::FacebookPage < ActiveRecord::Base
	validates_uniqueness_of :page_id, :message => "Page has been already added"
end
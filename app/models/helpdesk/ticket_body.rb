# Helpdesk::TicketBody is a tableless model
# Inherits ActiveRecord because to generate the default methods like intialize, new_record?
# Has following fields
# *description
# *description_html
# *raw_text
# *raw_html
# *meta_info
# *version
class Helpdesk::TicketBody < ActiveRecord::Base
  # creates a table less model
  has_no_table
  # For storing information if it is a new record or a changed record
  attr_accessor :new_record, :description_changed, :description_html_changed
  attr_accessor :raw_text_changed, :raw_html_changed, :meta_info_changed, :version_changed
  attr_accessor :account_id_changed, :ticket_id_changed, :created_at_changed, :updated_at_changed
  # columns needed to store in riak
  column :description, :text
  column :description_html, :text
  column :raw_text, :text
  column :raw_html, :text
  column :meta_info, :text 
  column :version, :text
  column :account_id, :integer
  column :ticket_id, :integer
  column :created_at, :datetime
  column :updated_at, :datetime

  # this method tells if it is a new record or old record
  def new_record?
    !self.new_record && !self.new_record.nil? ? false : true
  end

  # to identify if any parameter is changed from the last request
  def attributes_changed?
    (description_changed? || description_html_changed? || raw_text_changed? || 
    raw_html_changed? || meta_info_changed? || version_changed?) 
  end

  def reset_attribute_changed
    self.description_changed = false
    self.description_html_changed = false
    self.raw_text_changed = false
    self.raw_html_changed = false
    self.meta_info_changed = false
    self.version_changed = false
  end
  
end
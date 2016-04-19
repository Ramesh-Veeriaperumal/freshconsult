# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveTicketAssociation < ActiveRecord::Base
  has_no_table
  
  attr_accessor :description_changed, :description_html_changed, :association_data_changed, :account_id_changed
  attr_accessor :archive_ticket_id_changed, :subject_changed, :requester_id_changed, :responder_id_changed
  attr_accessor :source_changed, :status_changed, :group_id_changed, :priority_changed, :ticket_type_changed
  attr_accessor :display_id_changed, :ticket_id_changed, :access_token_changed, :owner_id_changed, :created_at_changed
  attr_accessor :updated_at_changed, :archive_created_at_changed, :archive_updated_at_changed 

  column :description, :text
  column :description_html, :text
  column :association_data, :text
  column :account_id, :integer
  column :archive_ticket_id, :integer
  column :subject, :text
  column :requester_id, :integer
  column :responder_id, :integer
  column :source, :integer
  column :status, :integer
  column :group_id, :integer
  column :priority, :integer
  column :ticket_type, :text
  column :display_id, :integer
  column :ticket_id, :integer
  column :access_token, :text
  column :owner_id, :integer
  column :created_at, :datetime
  column :updated_at, :datetime
  column :archive_created_at, :datetime
  column :archive_updated_at, :datetime
end
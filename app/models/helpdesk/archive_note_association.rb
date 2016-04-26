# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveNoteAssociation < ActiveRecord::Base
  has_no_table	
  
  attr_accessor :body_changed, :body_html_changed, :associations_data_changed, :archive_note_id_changed
  attr_accessor :user_id_changed, :archive_ticket_id_changed, :account_id_changed, :note_id_changed, :notable_id_changed
  attr_accessor :source_changed, :incoming_changed, :private_changed, :created_at_changed, :updated_at_changed

  column :body, :text
  column :body_html, :text
  column :associations_data, :text
  column :account_id, :integer
  column :archive_note_id, :integer
  column :user_id, :integer
  column :archive_ticket_id, :integer
  column :note_id, :integer
  column :notable_id, :integer
  column :source, :integer
  column :incoming, :tinyint
  column :private, :tinyint
  column :created_at, :datetime
  column :updated_at, :datetime
end
# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveNoteAssociation < ActiveRecord::Base
  self.primary_key = :id
  belongs_to_account
  belongs_to :archive_note, :class_name => 'Helpdesk::ArchiveNote' 

  serialize :associations_data
end
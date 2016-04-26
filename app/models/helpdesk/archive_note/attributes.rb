# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveNote < ActiveRecord::Base
  attr_accessor :archive_note_content
  
  def archive_note_association_attributes=(options={})
  	self.archive_note_content = Helpdesk::ArchiveNoteAssociation.new(options.merge({:archive_note_id => self.id}))
  end

  def archive_note_association
    self.archive_note_content ||= fetch
  end

  def fetch
    send("read_from_#{$archive_store}")
  end
end

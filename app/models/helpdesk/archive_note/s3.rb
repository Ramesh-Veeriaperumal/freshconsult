# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveNote < ActiveRecord::Base
  def read_from_s3
    object= Helpdesk::S3::ArchiveNote::Body.get_from_s3(self.account_id,self.id)
    s3_archive_note_body = Helpdesk::ArchiveNoteAssociation.new(object["archive_note_association"])
    return s3_archive_note_body
  end
end

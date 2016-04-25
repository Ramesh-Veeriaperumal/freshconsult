# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveTicket < ActiveRecord::Base
  
  def read_from_s3
    object= Helpdesk::S3::ArchiveTicket::Body.get_from_s3(self.account_id,self.id)
    s3_archive_ticket_body = Helpdesk::ArchiveTicketAssociation.new(object["archive_ticket_association"])
    return s3_archive_ticket_body
  end
end

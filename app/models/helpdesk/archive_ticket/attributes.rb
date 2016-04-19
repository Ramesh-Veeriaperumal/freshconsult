# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveTicket < ActiveRecord::Base
  attr_accessor :archive_ticket_content
  
  def archive_ticket_association_attributes=(options={})
  	self.archive_ticket_content = Helpdesk::ArchiveTicketAssociation.new(options.merge({:archive_ticket_id => self.id}))
  end

  def archive_ticket_association
    self.archive_ticket_content ||= fetch
  end

  def fetch
    send("read_from_#{$archive_store}")
  end
end

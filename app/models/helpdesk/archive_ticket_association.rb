# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveTicketAssociation < ActiveRecord::Base
  self.primary_key = :id
  belongs_to_account
  belongs_to :archive_ticket, :class_name => 'Helpdesk::ArchiveTicket' 

  serialize :association_data
end
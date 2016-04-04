# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveChild < ActiveRecord::Base
  self.table_name = "archive_childs"
  self.primary_key = :id
  belongs_to_account
  belongs_to :archive_ticket, :class_name => "Helpdesk::ArchiveTicket"
  belongs_to :ticket, :class_name => "Helpdesk::Ticket"
end
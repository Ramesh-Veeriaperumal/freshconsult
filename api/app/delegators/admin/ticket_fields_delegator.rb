class Admin::TicketFieldsDelegator < BaseDelegator
  include Admin::TicketFieldHelper

  attr_accessor :record

  def initialize(record, options = {})
    super(record, options)
  end
end

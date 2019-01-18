module Channel::V2
  class TicketFilterValidation < ::TicketFilterValidation
    attr_accessor :filter_id
    validates_presence_of :filter_id, message: 'Mandatory query param filter_id is missing'
    validates_numericality_of :filter_id, message: 'filter_id should be positive integer'
  end
end

class TicketAssociateValidation < ApiValidation
  attr_accessor :tracker_id

  validates :tracker_id, data_type: { rules: Integer }, required: true, on: :link
  validates :tracker_id, data_type: { rules: Integer }, required: true, on: :bulk_link

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end
end

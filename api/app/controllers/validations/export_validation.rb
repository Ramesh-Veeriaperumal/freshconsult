class ExportValidation < ApiValidation
  attr_accessor :created_at, :action

  validate :created_at_format, if: :ticket_activities_action?

  def initialize(request_params)
    super(request_params)
    @action = request_params[:action]
  end

  def ticket_activities_action?
    @action == 'ticket_activities'
  end

  def created_at_format
    return true if @created_at.nil? || DateTime.iso8601(@created_at).is_a?(DateTime)
  rescue ArgumentError => e
    errors[:created_at] << :datatype_mismatch
    error_options[:created_at] = { expected_data_type: DateTime, prepend_msg: :input_received, given_data_type: ExportConstants::DATA_TYPE_MAPPING[@created_at.class.to_s.to_sym] }
    return false
  end
end

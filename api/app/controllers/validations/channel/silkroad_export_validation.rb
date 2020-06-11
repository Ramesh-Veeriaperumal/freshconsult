module Channel
  class SilkroadExportValidation < ApiValidation
    include Silkroad::Constants::Ticket
    attr_accessor :job_id, :status

    validates :job_id, required: true, data_type: { rules: Integer, required: true }
    validates :status, required: true, custom_inclusion: { in: [SILKROAD_EXPORT_STATUS[:completed], SILKROAD_EXPORT_STATUS[:failed]] }

    def initialize(request_params)
      super(request_params)
    end
  end
end

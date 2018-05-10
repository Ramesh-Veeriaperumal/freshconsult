class ArchiveTicketExportValidation < ExportCsvValidation
  include ExportHelper
  attr_accessor :contact_fields, :company_fields, :ticket_fields,
                :query, :format, :export_name

  FORMAT = %w(csv xls).freeze

  validates :format, required: true, data_type: { rules: String }, custom_inclusion: { in: FORMAT }
  validates :query, required: true, data_type: { rules: String, allow_blank: false},
            custom_length: { maximum: MAX_QUERY_LIMIT , message_options: { element_type: :"long query"} }
  validates :export_name, required: true, data_type: { rules: String, allow_blank: false }

  validates :ticket_fields,
            data_type: { rules: Array, allow_blank: true },
            array: {
              data_type: { rules: String },
              custom_inclusion: { in: proc { |x| x.ticket_fields_list } }
            }

  validates :contact_fields,
            data_type: { rules: Array, allow_blank: true },
            array: {
              data_type: { rules: String },
              custom_inclusion: { in: proc { |x| x.contact_fields_list } }
            }

  validates :company_fields,
            data_type: { rules: Array, allow_blank: true },
            array: {
              data_type: { rules: String },
              custom_inclusion: { in: proc { |x| x.company_fields_list } }
            }

  validate :validate_request_params, if: -> { errors.blank? }
  validate :validate_query_format, if: -> { errors.blank? }


  def validate_request_params
    errors[:request] << :select_a_field if [*ticket_fields, *company_fields, *contact_fields].empty?
  end

  def validate_query_format
    response = Freshquery::Builder.new.check_query_validity({:query => "\"#{query}\"", :types => ['archiveticket']})
    unless response.valid?
      error_msg = response.errors.messages.map{|k,v| "#{k}:#{v}"}.join('. ')
      errors[:query] << error_msg 
    end
  end
end
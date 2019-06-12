class TicketExportValidation < ExportCsvValidation
  include ExportHelper

  attr_accessor :contact_fields, :company_fields, :ticket_fields,
                :query_hash, :format, :ticket_state_filter, :date_filter, :start_date, :end_date, :filter_name

  FORMAT = %w(csv xls).freeze
  DATE_FILTER = TicketConstants::CREATED_BY_NAMES_BY_KEY.keys.map(&:to_s)
  TICKET_STATE_FILTER = TicketConstants::STATES_HASH.keys.map(&:to_s)

  validates :format, required: true, data_type: { rules: String }, custom_inclusion: { in: FORMAT }
  validates :filter_name, data_type: { rules: String }, custom_inclusion: { in: TicketConstants::DEFAULT_FILTER_EXPORT }
  validates :date_filter, required: true, data_type: { rules: String }, custom_inclusion: { in: DATE_FILTER }
  validates :ticket_state_filter, required: true, data_type: { rules: String }, custom_inclusion: { in: TICKET_STATE_FILTER }
  validates :start_date, date_time: { allow_nil: false }
  validates :end_date, date_time: { allow_nil: false }

  validate :query_hash_presence

  validates :query_hash,
            data_type: { rules: Array, required: true, allow_blank: true },
            array: {
              data_type: { rules: Hash },
              allow_blank: true
            }, unless: -> { query_hash.nil? }
  # validate_query_hash moved to ApiValidation
  validate :validate_query_hash, unless: -> { query_hash.nil? }

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

  def query_hash_presence
    errors[:query_hash] << :missing_field if query_hash.nil?
  end

  def validate_request_params
    errors[:request] << :select_a_field if [*ticket_fields, *company_fields, *contact_fields].empty?
  end
end

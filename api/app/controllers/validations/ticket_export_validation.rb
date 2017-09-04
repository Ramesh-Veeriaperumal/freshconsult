class TicketExportValidation < ExportCsvValidation
  attr_accessor :contact_fields, :company_fields, :ticket_fields,
                :query_hash, :format, :ticket_state_filter, :date_filter, :start_date, :end_date

  FORMAT = %w(csv xls).freeze
  DATE_FILTER = TicketConstants::CREATED_BY_NAMES_BY_KEY.keys.map(&:to_s)
  TICKET_STATE_FILTER = TicketConstants::STATES_HASH.keys.map(&:to_s)
  DEFAULT_CONTACT_EXPORT_FIELDS = %w(name phone mobile).freeze
  DEFAULT_COMPANY_EXPORT_FIELDS = %w(name).freeze

  validates :format, required: true, data_type: { rules: String }, custom_inclusion: { in: FORMAT }
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

  def ticket_fields_list
    flexi_fields = Account.current.ticket_fields_from_cache.select { |x| x.default == false }.map(&:name).collect { |x| display_name(x, :ticket) }
    # Use EXP_TICKET_FIELDS once shared ownership fields added to ticket_scheduled_export
    default_fields = Helpdesk::TicketModelExtension.allowed_ticket_export_fields
    default_fields += ['product_name'] if Account.current.multi_product_enabled? # Changed to feature check as ember validation won't have product presence check
    default_fields + flexi_fields + ['description']
  end

  def contact_fields_list
    # Check privilege
    fields = if customer_export_privilege?
               default_contact_fields + custom_contact_fields
             else
               DEFAULT_CONTACT_EXPORT_FIELDS.map(&:clone)
             end
    fields << Helpdesk::TicketModelExtension.customer_fields('contact').map { |x| x[:value] }
    fields.flatten
  end

  def company_fields_list
    # Check privilege
    fields = if customer_export_privilege?
               default_company_fields + custom_company_fields
             else
               DEFAULT_COMPANY_EXPORT_FIELDS
             end
    fields.flatten
  end

  def query_hash_presence
    errors[:query_hash] << :missing_field if query_hash.nil?
  end

  def validate_request_params
    errors[:request] << :select_a_field if [*ticket_fields, *company_fields, *contact_fields].empty?
  end
end

class Sync::FileToData::Transformer
  include Helpdesk::Ticketfields::ControllerMethods
  include Sync::Transformer::Util
  include Sync::Transformer::SlaPolicy
  include Sync::Transformer::VaRule
  include Sync::Transformer::InlineAttachment

  TRANSFORMATIONS = {
    'Helpdesk::TicketField' => ['name', 'column_name'],
    'Helpdesk::NestedTicketField' => ['name'],
    'FlexifieldDef'               => ['name'],
    'FlexifieldDefEntry'          => ['flexifield_alias', 'flexifield_name'],
    'VaRule'                      => ['filter_data', 'action_data'],
    'Helpdesk::SlaPolicy'         => ['escalations', 'conditions'],
    'Helpdesk::TicketTemplate'    => ['template_data', 'data_description_html'],
    'Helpdesk::TicketStatus'      => ['status_id'],
    'Admin::Skill'                => ['filter_data'],
    'Admin::CannedResponses::Response' => ['content_html']
  }.freeze

  CUSTOM_TEXT_FIELDS_TYPES = {
    'dn_slt' => 'text',
    'ffs' => 'dropdown',
    'ff_int' => 'number',
    'ff_boolean' => 'checkbox',
    'ff_date' => 'date',
    'dn_mlt' => 'paragraph',
    'ff_decimal' => 'decimal'
  }.freeze

  TICKET_TEMPLATE_KEY_MODEL_MAPPING = {
    'responder_id' => 'User',
    'product_id'   => 'Product',
    'group_id'     => 'Group'
  }.freeze

  attr_accessor :master_account_id, :mapping_table, :account, :resync

  def initialize(master_account_id, resync = false, account = Account.current)
    @master_account_id    = master_account_id
    @account              = account
    @resync               = resync
    @max_ticket_status_id = get_max_ticket_status_id if resync
    find_available_ticket_field_columns if resync
    @mapping_table = {}
  end

  def available?(model, column)
    (TRANSFORMATIONS[model.to_s] || []).include?(column)
  end

  def transform_helpdesk_ticket_field_name(data, _mapping_table)
    change_custom_field_name(data)
  end

  def transform_flexifield_def_name(data, _mapping_table)
    change_custom_field_name(data)
  end

  def transform_helpdesk_nested_ticket_field_name(data, _mapping_table)
    change_custom_field_name(data)
  end

  def transform_flexifield_def_entry_flexifield_alias(data, _mapping_table)
    change_custom_field_name(data)
  end

  def transform_flexifield_def_entry_flexifield_name(data, _mapping_table)
    return data unless resync
    type = ticket_field_type(data)
    @available_ticket_filed_columns[type].delete(data) || @available_ticket_filed_columns[type].shift
  end

  def transform_helpdesk_ticket_status_status_id(data, _mapping_table)
    return data unless resync
    @max_ticket_status_id += 1
  end

  def transform_helpdesk_ticket_field_column_name(data, mapping_table)
    mapping_table['FlexifieldDefEntry']['flexifield_name'].try(:[], data) || data
  end

  def transform_admin_skill_filter_data(data, mapping_table)
    # Need to move va rule filter data logic to util.
    transform_va_rule_filter_data(data, mapping_table).map { |it| it.stringify_keys! }
  end

  def transform_helpdesk_ticket_template_template_data(data, mapping_table)
    @mapping_table = mapping_table
    data = Hash[data.map { |k, v| [change_custom_field_name(k), v] }]
    TICKET_TEMPLATE_KEY_MODEL_MAPPING.each do |key, model|
      if data[key].present?
        data[key] = apply_id_mapping(data[key], get_mapping_data(model, mapping_table))
      end
    end
    ActionController::Parameters.new(data)
  end

  private

    def ticket_field_type(data)
      CUSTOM_TEXT_FIELDS_TYPES[CUSTOM_TEXT_FIELDS_TYPES.keys.select { |type| data.include? type }[0]]
    end

    def find_available_ticket_field_columns
      @available_ticket_filed_columns = {}
      Helpdesk::Ticketfields::Constants::FIELD_COLUMN_MAPPING.keys.each do |type|
        @available_ticket_filed_columns[type.to_s] = available_columns(type)
      end
    end

    def get_max_ticket_status_id
      Account.current.ticket_statuses.maximum('status_id')
    end

    def change_custom_field_name(data)
      data = "#{Regexp.last_match(1)}_#{account.id}" if data =~ /(.*)_#{master_account_id}/
      data
    end
end

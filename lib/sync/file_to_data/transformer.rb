class Sync::FileToData::Transformer
  include Helpdesk::Ticketfields::ControllerMethods
  include Sync::Transformer::Util
  include Sync::Transformer::SlaPolicy
  include Sync::Transformer::VaRule
  include Sync::Transformer::InlineAttachment
  include Sync::Transformer::Social

  TRANSFORMATIONS = {
    'Helpdesk::TicketField'             => ['name', 'column_name'],
    'Helpdesk::NestedTicketField'       => ['name'],
    'FlexifieldDef'                     => ['name'],
    'FlexifieldDefEntry'                => ['flexifield_alias', 'flexifield_name'],
    'VaRule'                            => ['filter_data', 'action_data', 'condition_data', 'last_updated_by'],
    'Helpdesk::SlaPolicy'               => ['escalations', 'conditions'],
    'Helpdesk::TicketTemplate'          => ['template_data', 'data_description_html'],
    'Helpdesk::TicketStatus'            => ['status_id'],
    'Admin::Skill'                      => ['filter_data'],
    'Admin::CannedResponses::Response'  => ['content_html'],
    'EmailNotification'                 => ['requester_template', 'agent_template'],
    'Helpdesk::ParentChildTemplate'     => ['parent_template_id', 'child_template_id'],
    'Helpdesk::PicklistValue'           => ['picklist_id'],
    'Social::Stream'                    => ['data'],
    'Social::TicketRule'                => ['action_data'],
    'Social::TwitterHandle'             => ['state'],
    'Helpdesk::SectionPicklistValueMapping' => ['picklist_id']
  }.freeze

  CUSTOM_TEXT_FIELDS_TYPES = {
    'dn_slt'      => 'text',
    'ffs'         => 'dropdown',
    'ff_int'      => 'number',
    'ff_boolean'  => 'checkbox',
    'ff_date'     => 'date',
    'dn_mlt'      => 'paragraph',
    'ff_decimal'  => 'decimal',
  }.freeze

  TICKET_TEMPLATE_KEY_MODEL_MAPPING = {
    responder_id: 'User',
    product_id:   'Product',
    group_id:     'Group',
  }.freeze

  SKIP_TRANSFORMATION = [
    'Helpdesk::TicketStatus',
  ].freeze

  EXTRA_COLUMN_TO_ADD = {
    'Helpdesk::PicklistValue' => ['picklist_id']
  }.freeze

  attr_accessor :master_account_id, :mapping_table, :account, :resync

  def initialize(master_account_id, resync = false, clone = false, account = Account.current)
    @master_account_id        = master_account_id
    @account                  = account
    @resync                   = resync
    @clone                    = clone
    @mapping_table            = {}
    production_account_id     = resync ? account.id : master_account_id
    production_account_shard  = ShardMapping.fetch_by_account_id(production_account_id)
    shard_name                = temporary_offset_enabled? ? 'default' : production_account_shard.shard_name
    @offset_value             = Integer(SANDBOX_ID_OFFSET[shard_name] || SANDBOX_ID_OFFSET['default'])
    load_resync_dependent_vars if resync
  end

  def can_map_column?(model, column)
    (EXTRA_COLUMN_TO_ADD[model] || []).include?(column)
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
    transform_va_rule_filter_data(data, mapping_table)
  end

  def transform_helpdesk_ticket_template_template_data(data, mapping_table)
    @mapping_table = mapping_table
    data = data.symbolize_keys
    data = Hash[data.map { |k, v| [change_custom_field_name(k), v] }]
    data[:inherit_parent] = data[:inherit_parent].map { |k| change_custom_field_name(k) } if data[:inherit_parent]
    TICKET_TEMPLATE_KEY_MODEL_MAPPING.each do |key, model|
      if data[key].present?
        data[key] = apply_id_mapping(data[key], get_mapping_data(model, mapping_table))
      end
    end
    ActionController::Parameters.new(data)
  end

  def transform_helpdesk_picklist_value_picklist_id(data, _mapping_table)
    return data unless @resync

    @max_picklist_id += 1
  end

  def transform_helpdesk_section_picklist_value_mapping_picklist_id(data, _mapping_table)
    (get_mapping_data('Helpdesk::PicklistValue', _mapping_table, 'picklist_id') || {})[data]
  end

  def skip_transformation?(data, model = '')
    @clone || @resync || SKIP_TRANSFORMATION.include?(model)
  end

  ['Helpdesk::ParentChildTemplate'].each do |model|
    TRANSFORMATIONS[model].each do |column|
      define_method "transform_#{model.gsub('::', '').snakecase}_#{column}" do |data, mapping_table|
        apply_id_mapping(data, get_mapping_data('Helpdesk::TicketTemplate', mapping_table))
      end
    end
  end

  def calc_id(val, reverse = false)
    new_val = reverse ? val.to_i - @offset_value : val.to_i + @offset_value
    val.is_a?(String) ? new_val.to_s : new_val
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

    def fetch_max_ticket_status_id
      Account.current.ticket_statuses.maximum('status_id')
    end

    def fetch_max_picklist_id
      Account.current.picklist_values.maximum('picklist_id')
    end

    def change_custom_field_name(data)
      data = "#{Regexp.last_match(1)}_#{account.id}" if data =~ /(.*)_#{master_account_id}/
      data
    end

    def load_resync_dependent_vars
      @max_ticket_status_id = fetch_max_ticket_status_id
      @max_picklist_id = fetch_max_picklist_id
      find_available_ticket_field_columns
    end

    def temporary_offset_enabled?
      account.sandbox_temporary_offset_enabled? || LaunchParty.new.launched?(account: master_account_id, feature: :sandbox_temporary_offset)
    end
end

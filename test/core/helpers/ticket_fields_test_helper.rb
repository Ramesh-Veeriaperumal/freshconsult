module CoreTicketFieldsTestHelper
	include Helpdesk::Ticketfields::ControllerMethods

  FIELD_MAPPING = { 'number' => 'int', 'checkbox' => 'boolean', 'paragraph' => 'text', 'decimal' => 'decimal', 'date' => 'date', 'date_time' => 'date' }.freeze

  CHARACTER_FIELDS = (1..80).collect { |n| "ffs_#{"%02d" % n}" }
  NUMBER_FIELDS = (1..20).collect { |n| "ff_int#{"%02d" % n}" }
  DATE_FIELDS = (1..10).collect { |n| "ff_date#{"%02d" % n}" }
  CHECKBOX_FIELDS = (1..10).collect { |n| "ff_boolean#{"%02d" % n}" }
  TEXT_FIELDS = (1..10).collect { |n| "ff_text#{"%02d" % n}" }
  DECIMAL_FIELDS = (1..10).collect { |n| "ff_decimal#{"%02d" % n}" }

  # Whenever you add new fields here, ensure that you add it in search indexing.
  FIELD_COLUMN_MAPPING = {
    'text'         => [['text', 'dropdown'], CHARACTER_FIELDS],
    'nested_field' => [['text', 'dropdown'], CHARACTER_FIELDS],
    'dropdown'     => [['text', 'dropdown'], CHARACTER_FIELDS],
    'number'       => ['number', NUMBER_FIELDS],
    'checkbox'     => ['checkbox', CHECKBOX_FIELDS],
    'date'         => ['date', DATE_FIELDS],
    'date_time'    => ['date_time', DATE_FIELDS],
    'paragraph'    => ['paragraph', TEXT_FIELDS],
    'decimal'      => ['decimal', DECIMAL_FIELDS]
  }.freeze

  def create_custom_field(name, type, _required = false, _required_for_closure = false)
    ticket_field_exists = @account.ticket_fields.find_by_name("#{name}_#{@account.id}")
    return ticket_field_exists if ticket_field_exists
    flexifield_mapping = flexifield_mapping(type)
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry,
                                             flexifield_def_id: @account.flexi_field_defs.find_by_module('Ticket').id,
                                             flexifield_alias: "#{name.downcase}_#{@account.id}",
                                             flexifield_name: flexifield_mapping,
                                             flexifield_order: 5,
                                             flexifield_coltype: "#{type}",
                                             account_id: @account.id)
    flexifield_def_entry.save

    parent_custom_field = FactoryGirl.build(:ticket_field, account_id: @account.id,
                                                           name: "#{name.downcase}_#{@account.id}",
                                                           label: name,
                                                           label_in_portal: name,
                                                           field_type: "custom_#{type}",
                                                           description: '',
                                                           flexifield_def_entry_id: flexifield_def_entry.id)
    parent_custom_field.save
    parent_custom_field
  end

  def flexifield_mapping type
    ff_def = @account.ticket_field_def
    ff_def_entries = ff_def.flexifield_def_entries.all(:conditions => {
      :flexifield_coltype => FIELD_COLUMN_MAPPING[type][0] })

    used_columns = ff_def_entries.collect { |ff_entry| ff_entry.flexifield_name }
    available_columns = FIELD_COLUMN_MAPPING[type][1] - used_columns
    available_columns.first
  end

end

require_relative '../unit_test_helper'
require_relative '../../test_helper'
require_relative '../helpers/ticket_fields_test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class NestedFieldCorrectionTest < ActionView::TestCase
  include AccountHelper
  include TicketFieldsTestHelper

  def setup
    super
    @account = create_test_account
    @nested_field1 = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
    @nested_field2 = create_dependent_custom_field(%w[test_a test_b test_c], ff_number = 10)
  end

  def fetch_ffs_entry(nested_field)
    ffs_entries = []
    ffs_entries.push(nested_field.column_name)
    ffs_entries.push(*nested_field.child_levels.map(&:column_name))
    ffs_entries
  end

  def create_flexifield
    @tf_def ||= @account.ticket_field_def
    ff_field = if @account.ticket_field_limit_increase_enabled?
                 TicketFieldData.new(flexifield_def_id: @tf_def.id, flexifield_set_type: 'Helpdesk::Ticket')
               else
                 Flexifield.new(flexifield_def_id: @tf_def.id, flexifield_set_type: 'Helpdesk::Ticket')
               end
    ff_field.save!
    ff_field
  end

  def associate_values_to_nested_field(flexifield, ff_entries, ticket_field)
    choices = custom_nested_field_choices[ticket_field.name]
    if @account.ticket_field_limit_increase_enabled?
      flexifield.safe_send("#{ff_entries[0]}=", picklist_value_transformer[choices.keys[0].downcase])
      flexifield.safe_send("#{ff_entries[1]}=", picklist_value_transformer[choices[choices.keys[0]].keys[0].downcase])
      flexifield.safe_send("#{ff_entries[2]}=", picklist_value_transformer[choices[choices.keys[0]].values[0][0].downcase])
    else
      flexifield.safe_send("#{ff_entries[0]}=", choices.keys[0])
      flexifield.safe_send("#{ff_entries[1]}=", choices[choices.keys[0]].keys[0])
      flexifield.safe_send("#{ff_entries[2]}=", choices[choices.keys[0]].values[0][0])
    end
    flexifield.save(validate: false)
  end

  def picklist_value_transformer
    @picklist_value_transformer ||= @account.picklist_values.each_with_object({}) { |pv, h| h[pv.value.downcase] = pv.picklist_id }
  end

  def custom_nested_field_choices
    @custom_nested_field_choices ||= @account.custom_nested_field_choices_hash_from_cache
  end

  def modify_ffs_name_for_ticket_field(ticket_field, ffs_names)
    ticket_field.column_name = ticket_field.flexifield_def_entry.flexifield_name = ffs_names[0]
    ticket_field.child_levels[0].column_name = ticket_field.child_levels[0].flexifield_def_entry.flexifield_name = ffs_names[1]
    ticket_field.child_levels[1].column_name = ticket_field.child_levels[1].flexifield_def_entry.flexifield_name = ffs_names[2]
    ticket_field.save!
  end

  def launch_ticket_field_limit_increase
    @account.launch :ticket_field_limit_increase
    @account.launch :id_for_choices_write
    yield
  ensure
    @account.rollback :ticket_field_limit_increase
    @account.rollback :id_for_choices_write
  end

  def test_skip_clear_levels_on_normal_entries
    flexifield = create_flexifield
    ffs_entries = fetch_ffs_entry(@nested_field1)
    associate_values_to_nested_field(flexifield, ffs_entries, @nested_field1)
    flexifield.safe_send("#{fetch_ffs_entry(@nested_field2)[0]}=", Faker::Lorem.word)
    NestedFieldCorrection.new(flexifield).clear_child_levels
    ffs_entries.each do |ff_entry|
      assert flexifield.safe_send(ff_entry).present?
    end
  ensure
    flexifield.destroy
  end

  def test_clear_all_levels_on_first_level_change
    flexifield = create_flexifield
    ffs_entries = fetch_ffs_entry(@nested_field1)
    associate_values_to_nested_field(flexifield, ffs_entries, @nested_field1)
    flexifield.safe_send("#{ffs_entries[0]}=", nil)
    NestedFieldCorrection.new(flexifield).clear_child_levels
    ffs_entries.each do |ff_entry|
      assert flexifield.safe_send(ff_entry).nil?
    end
  ensure
    flexifield.destroy
  end

  def test_clear_second_and_third_level_on_first_level_change
    flexifield = create_flexifield
    ffs_entries = fetch_ffs_entry(@nested_field1)
    associate_values_to_nested_field(flexifield, ffs_entries, @nested_field1)
    flexifield.safe_send("#{ffs_entries[0]}=", custom_nested_field_choices[@nested_field1.name].keys[1])
    NestedFieldCorrection.new(flexifield).clear_child_levels
    assert flexifield.safe_send(ffs_entries[0]).present?
    assert flexifield.safe_send(ffs_entries[1]).nil?
    assert flexifield.safe_send(ffs_entries[2]).nil?
  ensure
    flexifield.destroy
  end

  def test_clear_third_level_on_first_two_levels_change
    flexifield = create_flexifield
    ffs_entries = fetch_ffs_entry(@nested_field1)
    associate_values_to_nested_field(flexifield, ffs_entries, @nested_field1)
    choices = custom_nested_field_choices[@nested_field1.name]
    flexifield.safe_send("#{ffs_entries[0]}=", choices.keys[1])
    flexifield.safe_send("#{ffs_entries[1]}=", choices[choices.keys[1]].keys[0])
    NestedFieldCorrection.new(flexifield).clear_child_levels
    assert flexifield.safe_send(ffs_entries[0]).present?
    assert flexifield.safe_send(ffs_entries[1]).present?
    assert flexifield.safe_send(ffs_entries[2]).nil?
  ensure
    flexifield.destroy
  end

  def test_skip_clear_child_levels_on_tf_limit_increase
    launch_ticket_field_limit_increase do
      @flexifield = create_flexifield
      ffs_entries = fetch_ffs_entry(@nested_field1)
      associate_values_to_nested_field(@flexifield, ffs_entries, @nested_field1)
      @flexifield.safe_send("#{fetch_ffs_entry(@nested_field2)[0]}=", rand(999))
      read_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::IdToString.new(@flexifield.flexifield_set)
      NestedFieldCorrection.new(@flexifield, read_transformer).clear_child_levels
      ffs_entries.each do |ff_entry|
        assert @flexifield.safe_send(ff_entry).present?
      end
    end
  ensure
    @flexifield.destroy
  end

  def test_clear_child_levels_on_tf_limit_increase
    launch_ticket_field_limit_increase do
      @flexifield = create_flexifield
      ffs_entries = fetch_ffs_entry(@nested_field1)
      associate_values_to_nested_field(@flexifield, ffs_entries, @nested_field1)
      @flexifield.safe_send("#{ffs_entries[0]}=", nil)
      read_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::IdToString.new(@flexifield.flexifield_set)
      NestedFieldCorrection.new(@flexifield, read_transformer).clear_child_levels
      ffs_entries.each do |ff_entry|
        assert @flexifield.safe_send(ff_entry).nil?
      end
    end
  ensure
    @flexifield.destroy
  end

  def test_clear_second_and_third_level_on_first_level_change_limit_increased_fields
    launch_ticket_field_limit_increase do
      modify_ffs_name_for_ticket_field(@nested_field1, ['ffs_100', 'ffs_101', 'ffs_102'])
      choices = custom_nested_field_choices[@nested_field1.name]
      @flexifield = create_flexifield
      ffs_entries = fetch_ffs_entry(@nested_field1)
      associate_values_to_nested_field(@flexifield, ffs_entries, @nested_field1)
      @flexifield.safe_send("#{ffs_entries[0]}=", picklist_value_transformer[choices.keys[1].downcase])
      read_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::IdToString.new(@flexifield.flexifield_set)
      NestedFieldCorrection.new(@flexifield, read_transformer).clear_child_levels
      assert @flexifield.safe_send(ffs_entries[1]).nil?
      assert @flexifield.safe_send(ffs_entries[2]).nil?
    end
  ensure
    @flexifield.destroy
    modify_ffs_name_for_ticket_field(@nested_field1, ['ffs_07', 'ffs_08', 'ffs_09'])
  end

  def test_clear_third_level_on_first_two_levels_change_limit_increased_fields
    launch_ticket_field_limit_increase do
      modify_ffs_name_for_ticket_field(@nested_field1, ['ffs_100', 'ffs_101', 'ffs_102'])
      choices = custom_nested_field_choices[@nested_field1.name]
      @flexifield = create_flexifield
      ffs_entries = fetch_ffs_entry(@nested_field1)
      associate_values_to_nested_field(@flexifield, ffs_entries, @nested_field1)
      @flexifield.safe_send("#{ffs_entries[0]}=", picklist_value_transformer[choices.keys[1].downcase])
      @flexifield.safe_send("#{ffs_entries[0]}=", picklist_value_transformer[choices[choices.keys[1]].keys[0].downcase])
      read_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::IdToString.new(@flexifield.flexifield_set)
      NestedFieldCorrection.new(@flexifield, read_transformer).clear_child_levels
      assert @flexifield.safe_send(ffs_entries[2]).nil?
    end
  ensure
    @flexifield.destroy
    modify_ffs_name_for_ticket_field(@nested_field1, ['ffs_07', 'ffs_08', 'ffs_09'])
  end

  def test_skip_clear_child_levels_for_limit_increased_fields
    launch_ticket_field_limit_increase do
      modify_ffs_name_for_ticket_field(@nested_field1, ['ffs_100', 'ffs_101', 'ffs_102'])
      modify_ffs_name_for_ticket_field(@nested_field2, ['ffs_110', 'ffs_111', 'ffs_112'])
      @flexifield = create_flexifield
      ffs_entries = fetch_ffs_entry(@nested_field1)
      associate_values_to_nested_field(@flexifield, ffs_entries, @nested_field1)
      @flexifield.safe_send("#{fetch_ffs_entry(@nested_field2)[0]}=", rand(999))
      read_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::IdToString.new(@flexifield.flexifield_set)
      NestedFieldCorrection.new(@flexifield, read_transformer).clear_child_levels
      ffs_entries.each do |ff_entry|
        assert @flexifield.safe_send(ff_entry).present?
      end
    end
  ensure
    @flexifield.destroy
    modify_ffs_name_for_ticket_field(@nested_field1, ['ffs_07', 'ffs_08', 'ffs_09'])
    modify_ffs_name_for_ticket_field(@nested_field2, ['ffs_10', 'ffs_11', 'ffs_12'])
  end

  def test_clear_child_levels_for_limit_increased_fields
    launch_ticket_field_limit_increase do
      modify_ffs_name_for_ticket_field(@nested_field1, ['ffs_100', 'ffs_101', 'ffs_102'])
      modify_ffs_name_for_ticket_field(@nested_field2, ['ffs_110', 'ffs_111', 'ffs_112'])
      @flexifield = create_flexifield
      ffs_entries = fetch_ffs_entry(@nested_field1)
      associate_values_to_nested_field(@flexifield, ffs_entries, @nested_field1)
      @flexifield.safe_send("#{ffs_entries[0]}=", nil)
      read_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::IdToString.new(@flexifield.flexifield_set)
      NestedFieldCorrection.new(@flexifield, read_transformer).clear_child_levels
      ffs_entries.each do |ff_entry|
        assert @flexifield.safe_send(ff_entry).nil?
      end
    end
  ensure
    @flexifield.destroy
    modify_ffs_name_for_ticket_field(@nested_field1, ['ffs_07', 'ffs_08', 'ffs_09'])
    modify_ffs_name_for_ticket_field(@nested_field2, ['ffs_10', 'ffs_11', 'ffs_12'])
  end
end

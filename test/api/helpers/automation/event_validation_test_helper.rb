require "#{Rails.root}/test/api/helpers/json_pattern.rb"

module Automation::EventValidationTestHelper
  include JsonPattern
  include Admin::AutomationConstants

  def valid_from_to_hash
    data = []
    from_to_fields.each do |field|
      expected_values = valid_data_list(field[:name], field[:data_type])
      expected_values.each_with_index do |first, index1|
        expected_values.each_with_index do |second, index2|
          next if index1 >= index2 && first != '--'
          data << { field_name: field[:name], from: first, to: second }
        end
      end
    end
    data
  end

  def invalid_from_to_hash
    data = []
    from_to_fields.each do |field|
      expected_values = invalid_data_list(field[:name], field[:data_type])
      expected_values.each_with_index do |first, index1|
        expected_values.each_with_index do |second, index2|
          next if index1 >= index2
          data << { field_name: field[:name], from: first, to: second }
        end
      end
      expected_values = valid_data_list(field[:name], field[:data_type])
      expected_values.each do |first|
        next if first == '--'
        data << { field_name: field[:name], from: first, to: first }
      end
    end
    data
  end

  def missing_from_to_hash
    data = []
    from_to_fields.each do |field|
      expected_values = valid_data_list(field[:name], field[:data_type])
      expected_values.each do |first|
        data << { field_name: field[:name], to: first }
        data << { field_name: field[:name], from: first }
        data << { field_name: field[:name] }
      end
    end
    data
  end

  def extra_field_value_in_case_of_from_to
    data = []
    from_to_fields.each do |field|
      expected_values = valid_data_list(field[:name], field[:data_type])
      expected_values.each_with_index do |first, index1|
        expected_values.each_with_index do |second, index2|
          next if index1 >= index2 && first != '--'
          data << { field_name: field[:name], from: first, to: second, value: first }
          data << { field_name: field[:name], from: first, value: second }
          data << { field_name: field[:name], to: second, value: first }
        end
      end
    end
    data
  end

  def valid_field_value_hash
    data = []
    value_type_fields.each do |field|
      expected_values = valid_data_list(field[:name], field[:data_type])
      expected_values.each do |value|
        data << { field_name: field[:name], value: value }
      end
    end
    data
  end

  def invalid_field_value_hash
    data = []
    value_type_fields.each do |field|
      expected_values = invalid_data_list(field[:name], field[:data_type])
      expected_values.each do |value|
        data << { field_name: field[:name], value: value }
      end
    end
    data
  end

  def missing_field_value_hash
    data = []
    value_type_fields.each do |field|
      data << { field_name: field[:name] }
    end
    data
  end

  def extra_field_from_to_in_case_of_value
    data = []
    value_type_fields.each do |field|
      expected_values = valid_data_list(field[:name], field[:data_type])
      expected_values.each do |value|
        data << { field_name: field[:name], value: value, from: value, to: value}
        data << { field_name: field[:name], value: value, from: value }
        data << { field_name: field[:name], value: value, to: value }
      end
    end
    data
  end

  def valid_label_type_hash
    data = []
    label_type_fields.each do |field|
      data << { field_name: field[:name] }
    end
    data
  end

  def invalid_field_label_hash
    data = []
    label_type_fields.each do |field|
      expected_values = invalid_data_list(field[:name], field[:data_type])
      expected_values.each do |value|
        data << { field_name: field[:name], from: value, to: value}
        data << { field_name: field[:name], value: value }
      end
    end
    data
  end

  def valid_system_event_hash
    data = []
    system_event_fields.each do |field|
      data << { field_name: field[:name] }
    end
    data
  end

  def invalid_system_event_hash
    data = []
    system_event_fields.each do |field|
      expected_values = invalid_data_list(field[:name], field[:data_type])
      expected_values.each do |value|
        data << { field_name: field[:name], from: value, to: value}
        data << { field_name: field[:name], value: value }
      end
    end
    data
  end

  def error_pattern(errors, error_options); end

  private

    def from_to_fields
      @from_to_fields ||= EVENT_FIELDS_HASH.select { |field| field[:expect_from_to] }
    end

    def value_type_fields
      @value_type_fields ||= EVENT_FIELDS_HASH.select { |field| !field[:expect_from_to] && field[:field_type] == :dropdown }
    end

    def system_event_fields
      @system_event_fields ||= EVENT_FIELDS_HASH.select { |field| SYSTEM_EVENT_FIELDS.include?(field[:name]) }
    end

    def label_type_fields
      @label_type_fields ||= EVENT_FIELDS_HASH.select do |field|
        !SYSTEM_EVENT_FIELDS.include?(field[:name]) && field[:field_type] == :label
      end
    end

    def valid_data_list(name, type = nil, internal_type = nil)
      list = []
      list << Faker::Number.number(rand(5..15)).to_i if type == :Integer
      list << Faker::Number.number(rand(5..15)).to_i if type == :Integer
      list << [Faker::Number.number(rand(5..15)).to_i] if type == :Array && internal_type == :Integer
      list << [Faker::Number.number(rand(5..15)).to_i] if type == :Array && internal_type == :Integer
      list << Faker::Lorem.characters(rand(5..20)) if type == :String
      list << Faker::Lorem.characters(rand(5..20)) if type == :String
      list << [Faker::Lorem.characters(rand(5..20))] if type == :Array && internal_type == :String
      list << [Faker::Lorem.characters(rand(5..20))] if type == :Array && internal_type == :String
      list << '--' if EVENT_ANY_FIELDS.include?(name)
      list << '' if EVENT_NONE_FIELDS.include?(name)
      list
    end

    def invalid_data_list(name, type = nil)
      list = []
      list << Faker::Number.number(rand(5..15)).to_i unless type == :Integer
      list << Faker::Number.number(rand(5..15)).to_i unless type == :Integer
      list << [Faker::Number.number(rand(5..15)).to_i] unless type == :Array && internal_type == :Integer
      list << [Faker::Number.number(rand(5..15)).to_i] unless type == :Array && internal_type == :Integer
      list << Faker::Lorem.characters(rand(5..20)) unless type == :String
      list << Faker::Lorem.characters(rand(5..20)) unless type == :String
      list << [Faker::Lorem.characters(rand(5..20))] unless type == :Array && internal_type == :String
      list << [Faker::Lorem.characters(rand(5..20))] unless type == :Array && internal_type == :String
      list << '--' unless EVENT_ANY_FIELDS.include?(name)
      list << '' unless EVENT_NONE_FIELDS.include?(name)
      list
    end

    def write_to_file(data)
      # write_to_file(data) # only for testing purpose, check the request data
      file = File.open('newly.yml', 'w+')
      file.write YAML.dump(data)
      file.close
    end

    def group_by_error_count(errors, names)
      fields = {}
      names.each do |name|
        fields[name] = errors.keys.count {|value| value.include? name}
      end
      fields
    end

    def group_by_field_name(list)
      fields = {}
      list.each do |key|
        fields[key[:field_name]] ||= 0
        fields[key[:field_name]] += 1
      end
      fields
    end
end

module SegmentsHelper
  FIELD_TYPE_TO_TYPE_MAPPING = {
    custom_checkbox: 'checkbox',
    custom_number:   'number',
    custom_dropdown: 'dropdown'
  }

  def create_custom_field(type, options = {})
    field = field_scoper.custom_fields.where(field_type: CustomFields::Constants::CUSTOM_FIELD_PROPS[type][:type]).first
    return field if field.present? && !options[:force_new]

    # Hack to gsub prefix cf_, to pass segment validation
    label = ''
    loop do
      label = Faker::Name.name
      break unless label.start_with?('cf ')
    end

    params = { type: FIELD_TYPE_TO_TYPE_MAPPING[type], label: label, field_type: type, position: 100, custom_field_choices_attributes: [] }

    options[:choices].each_with_index do |choice, i|
      params[:custom_field_choices_attributes] << {
        value: choice,
        position: i + 1,
        name: choice,
        destroy: 0
      }
    end if options[:choices]

    field = field_scoper.custom_fields.create_field(params)
    field.reload
  end

  def create_segment(input_params)
    fields = []
    conditions = input_params.map do |param|
      temp_hash = { value: param[:value], operator: param[:operator] }
      if allowed_default_fields.include?(param[:name])
        fields << all_fields.find { |field| field.name == param[:name] }
        temp_hash.merge!({ condition: param[:name], type: 'default' })
      elsif Segments::FilterDataConstants::ALLOWED_CUSTOM_FIELD_TYPES.include?(param[:name])
        options = param[:options] || {}
        options[:force_new] = true if force_new?(param)
        field = create_custom_field(param[:name].to_sym, options) if options[:create_field] != false
        fields << field
        temp_hash.merge!({ condition: field.name.gsub('cf_', ''), type: 'custom_field' })
      end
      temp_hash
    end
    filter_hash = { name: Faker::Lorem.word, data: conditions.map(&:stringify_keys) }
    segment = segment_scoper.new(filter_hash)
    segment.save(validate: false) unless segment.save
    segment.reload
    [segment, fields]
  end

  def account
    Account.current
  end

  def force_new?(param)
    param[:name] == 'custom_dropdown'
  end
end

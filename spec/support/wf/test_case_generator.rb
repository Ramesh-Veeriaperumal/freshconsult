module Wf::TestCaseGenerator

  REJECT_KEYS = [:is_in, :options, :container, :field_type, :field_id, :nested_fields]

  def define_test_cases
    @filter_test_cases = []
    filter_options.each do |name, filter_details|
      next if name.to_s.to_sym == :created_at # :created_at test_cases are in tickets_controller_spec
      filter_hash = filter_details.reject { |key, value| REJECT_KEYS.include?(key) }
      ff_name = filter_hash[:ff_name]
      field_name = (ff_name != 'default') ? ff_name : name
      
      correct_option = select_correct_option field_name
      random_option  = select_random_option(options(name), correct_option)

      filter_hash[:value] = correct_option.to_s
      @filter_test_cases << filter_hash.dup

      filter_hash[:value] = random_option.to_s
      @filter_test_cases << filter_hash
    
      add_filters_for_nested_fields(filter_details) if filter_details[:nested_fields]
    end
  end

  def filter_options
    @filter_options ||= begin
      filters_array = @filters.map { |filter| [filter[:name], filter] }.flatten
      Hash[*filters_array]
    end
  end

  def options name
    method = :"options_for_#{name}"
    respond_to?(method) ? send(method) : filter_options[name][:options]
  end

  def options_for_customers
    @account.customers.all.map { |company| [company.id, company.name] }
  end

  def options_for_requester
    @account.users.contacts.all.map { |contact| [contact.id, contact.name] }
  end

  def add_filters_for_nested_fields filter_details
    @nested_field_options = filter_details[:options].dup
    @nested_field_options.delete_at(0) # removing 'any' options
    filter_details[:nested_fields].each do |filter_hash|
      ff_name = filter_hash[:ff_name]
      field_name = (ff_name != 'default') ? ff_name : name
      @nested_field_options = @nested_field_options.map{|x| x[2] }[0] # code repetition except this line.. ll check later

      correct_option = select_correct_option field_name
      random_option  = select_random_option(@nested_field_options, correct_option)

      filter_hash[:value] = correct_option.to_s
      @filter_test_cases << filter_hash.dup

      filter_hash[:value] = random_option.to_s
      @filter_test_cases << filter_hash
    end
  end

end

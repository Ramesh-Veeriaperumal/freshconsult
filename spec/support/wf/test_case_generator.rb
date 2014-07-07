module Wf::TestCaseGenerator

  SKIPPED_KEYS = [:is_in, :options, :container]

  def define_test_cases
    @filter_test_cases = []
    filter_options.each do |name, filter_details|
      next if name.to_s.to_sym == :created_at # :created_at test_cases are in tickets_controller_spec
      filter_hash = filter_details.reject { |key, value| SKIPPED_KEYS.include?(key) }
      correct_option = select_correct_option(name, options(name))
      random_option  = select_random_option(options(name), correct_option)

      filter_hash[:value] = correct_option.to_s
      @filter_test_cases << filter_hash.dup

      filter_hash[:value] = random_option.to_s
      @filter_test_cases << filter_hash
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

end

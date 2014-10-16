class VA::TestCase

  include AccountHelper
  include UsersHelper
  include VA::RuleHelper

  def count
    before_each
    @controller_options, @test_cases = {}, {}
    # Summing up all options for simplicity, Supervisor Options makes it hard to compare if individually done
    TESTS.each do |test_name, details|
      test_variable = details[:test_variable]
      module_to_be_included = details[:test_cases].first
      self.class.send :include, module_to_be_included
      create_required_objects
      define_options
      @controller_options.merge!(send(test_variable))
      @test_cases.merge!(@options.merge(@option_exceptions))
    end

    differences = @controller_options.keys - @test_cases.keys

    differences = remove_custom_fields(differences) # remove/refactor after writing test cases for custom fields
    unless differences == []
      p "Test cases should be written for VA::Options : #{differences.join(',')}"
      raise "Test cases should be written for VA::Options : #{differences.join(',')}"
    end
  end

  def check_rules
    TESTS.each do |test_name, details|
      before_each
      tester_class = details[:tester_class]
      modules_to_be_included = details[:test_cases]
      test_variable = details[:test_variable]
      tester = tester_class.new(send test_variable)

      modules_to_be_included.each do |module_to_be_included|
        self.class.send :include, module_to_be_included
        create_required_objects
        define_options
        @options.merge(@option_exceptions).each do |option_name, option_hash|
          begin
            clear_background_jobs
            tester.perform @ticket, option_name, option_hash, op_types
          rescue Exception => e
            p "Failed while checking the rules of VA Option : #{option_name} in VARule for the ticket #{@ticket.inspect}"
            raise "Error #{e.inspect} while checking the rules of VA Option : #{option_name} in VARule for the ticket #{@ticket.inspect}"
          end
        end
      end
    end
  end

  private

    def remove_custom_fields differences
      return differences - @account.ticket_fields_with_nested_fields.custom_fields.map(&:name).map(&:to_sym) - @account.event_flexifields_with_ticket_fields_from_cache.map(&:flexifield_name).map(&:to_sym)
    end

end
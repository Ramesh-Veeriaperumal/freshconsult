require_relative '../../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'

class SlaTimesTest < ActiveSupport::TestCase
  def setup
    super
    @account = create_test_account if @account.nil?
  end

  def test_populate_sla_times
    Migration::PopulateSlaTimes.new(account_id: @account.id).perform
    @account.sla_policies.each do |sp|
      sp.sla_details.each do |sd|
        assert_not_nil sd.sla_target_time
        assert_equal sd.convert_to_iso_format(sd.response_time), sd.sla_target_time[:first_response_time]
        assert_equal sd.convert_to_iso_format(sd.resolution_time), sd.sla_target_time[:resolution_due_time]
      end
    end
  end
end

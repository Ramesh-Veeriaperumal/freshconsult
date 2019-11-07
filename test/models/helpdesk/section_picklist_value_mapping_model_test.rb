require_relative '../test_helper'

class SectionPicklistValueMappingModelTest < ActiveSupport::TestCase

  def test_picklist_id_population
    Migration::PopulateSectionPicklistMappingPicklistId.new(account_id: @account.id).perform
    expected_ids = populated_ids = []
    Helpdesk::SectionPicklistValueMapping.where(account_id: @account_id).each do |mapping|
      expected_ids << mapping.picklist_value.picklist_id
      populated_ids << mapping.picklist_id
    end
    expected_ids.sort.must_equal populated_ids.sort
  end
end
require_relative '../test_helper'

class SectionModelTest < ActiveSupport::TestCase

  def test_parent_ticket_field_id_population
    Migration::PopulateParentTicketFieldId.new(account_id: @account.id).perform
    expected_ids = populated_ids = []
    @account.sections.each do |section|
      expected_ids << section.section_picklist_mappings[0].picklist_value.pickable_id
      populated_ids << section.ticket_field_id
    end
    expected_ids.sort.must_equal populated_ids.sort
  end
end
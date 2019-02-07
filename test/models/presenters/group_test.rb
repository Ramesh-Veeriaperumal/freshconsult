require_relative '../test_helper'

class GroupTest < ActiveSupport::TestCase
  include GroupsTestHelper

  def test_central_publish_payload
    group = create_group(@account)
    payload = group.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_group_pattern(group))
    assoc_payload = group.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(group_associations(group))
  end

  def test_central_publish_destroy_payload
    group = create_group(@account)
    group.destroy

    job = CentralPublisher::Worker.jobs.last
    assert_equal 'group_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_group_pattern(group))
  end

  private

    def group_associations(group)
      {
        business_calendar: business_calendar(group)
      }
    end

    def business_calendar(group)
      return nil unless group.business_calendar_id
      {
        name: group.name,
        description: group.description,
        time_zone: group.time_zone,
        is_default: group.is_default
      }
    end
end

require_relative '../test_helper'

class GroupTest < ActiveSupport::TestCase
  include GroupsTestHelper
  include UsersTestHelper

  def test_central_publish_create_payload
    group = create_group(@account)
    payload = group.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_group_pattern(group))
    assoc_payload = group.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(group_associations(group))
  end

  def test_central_publish_update_payload
    group = create_group(@account)
    group.reload
    CentralPublisher::Worker.jobs.clear
    oldName, newName = group.name, Faker::Lorem.word
    group.update_attributes(name: newName)
    assert_equal 1, CentralPublisher::Worker.jobs.size
    job = CentralPublisher::Worker.jobs.last
    payload = group.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_group_pattern(group))
    assert_equal 'group_update', job['args'][0]
    assert_equal({ 'name' => [oldName, newName] }, job['args'][1]['model_changes'])
  end

  def test_central_publish_payload_add_agents
    new_agent = add_agent(@account, role: Role.find_by_name('Agent').id)
    group = create_group(@account)
    group.reload
    CentralPublisher::Worker.jobs.clear
    group.agent_groups.build(user_id: new_agent.id)
    group.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
    job = CentralPublisher::Worker.jobs.last
    payload = group.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_group_pattern(group))
    assert_equal 'group_update', job['args'][0]
    assert_equal({ 'agents' => {'added' => [{'id' => new_agent.id, 'name' => new_agent.name}], 'removed' => [] } }, job['args'][1]['model_changes'])
  end

  def test_central_publish_destroy_payload
    group = create_group(@account)
    group.destroy

    job = CentralPublisher::Worker.jobs.last
    assert_equal 'group_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_group_destroy_pattern(group))
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

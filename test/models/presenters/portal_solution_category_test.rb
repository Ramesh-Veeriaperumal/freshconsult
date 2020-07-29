require_relative '../test_helper'

class PortalSolutionCategoryTest < ActiveSupport::TestCase
  include ModelsSolutionsTestHelper

  def test_create_portal_solution_category_on_category_create
    portal1 = create_portal
    CentralPublisher::Worker.jobs.clear
    category_meta = create_category(portal_ids: [portal1.id])
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'portal_solution_category_create', job['args'][0]
    payload = category_meta.portal_solution_categories.first.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_portal_solution_category_pattern(category_meta.portal_solution_categories.first))
  end

  def test_create_portal_solution_category_on_portal_create
    CentralPublisher::Worker.jobs.clear
    portal1 = create_portal
    job = CentralPublisher::Worker.jobs.last
    assert_equal 1, CentralPublisher::Worker.jobs.size
    assert_equal 'portal_solution_category_create', job['args'][0]
    payload = portal1.portal_solution_categories.last.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_portal_solution_category_pattern(portal1.portal_solution_categories.last))
  end

  def test_create_portal_solution_category_on_category_update
    portal1 = create_portal
    portal2 = create_portal
    portal3 = create_portal
    category_meta = create_category(portal_ids: [portal1.id, portal2.id])
    CentralPublisher::Worker.jobs.clear
    # Adding portal to category
    category_meta.portal_solution_categories_attributes= { portal_id: [portal1.id, portal2.id, portal3.id] }
    assert_equal 2, CentralPublisher::Worker.jobs.size
  end

  def test_create_portal_solution_category_on_portal_update
    portal1 = create_portal
    portal2 = create_portal
    category_meta = create_category(portal_ids: [portal1.id])
    job = CentralPublisher::Worker.jobs.clear
    # Adding category to a portal
    portal2.solution_category_metum_ids= [category_meta.id.to_s]
    portal2.save
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'portal_solution_category_create', job['args'][0]
    payload = portal2.portal_solution_categories.last.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_portal_solution_category_pattern(portal2.portal_solution_categories.last))
  end

  def test_destroy_portal_solution_category_on_category_update
    portal1 = create_portal
    portal2 = create_portal
    category_meta = create_category(portal_ids: [portal1.id, portal2.id])
    CentralPublisher::Worker.jobs.clear
    portal_sol_cat = category_meta.portal_solution_categories.select { |c| c.portal_id == portal2.id }.first
    # Removing portal from category
    category_meta.portal_solution_categories_attributes= { portal_id: [portal1.id] }
    assert_equal 2, CentralPublisher::Worker.jobs.size
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'portal_solution_category_destroy', job['args'][0]
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_portal_solution_category_destroy(portal_sol_cat))
  end

  def test_destroy_portal_solution_category_on_portal_update
    portal1 = create_portal
    category_meta = create_category(portal_ids: [portal1.id])
    category_meta2 = create_category(portal_ids: [portal1.id])
    CentralPublisher::Worker.jobs.clear
    portal_sol_cat = portal1.portal_solution_categories.select { |c| c.solution_category_meta_id == category_meta2.id }.first
    # Removing category from portal
    portal1.solution_category_metum_ids= [category_meta.id.to_s]
    portal1.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'portal_solution_category_destroy', job['args'][0]
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_portal_solution_category_destroy(portal_sol_cat))
  end

  def test_destroy_portal_solution_category_on_category_destroy
    portal1 = create_portal
    category_meta = create_category(portal_ids: [portal1.id])
    portal_sol_cat = category_meta.portal_solution_categories.first
    CentralPublisher::Worker.jobs.clear
    category_meta.destroy
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'portal_solution_category_destroy', job['args'][0]
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_portal_solution_category_destroy(portal_sol_cat))
  end

  def test_destroy_portal_solution_category_on_portal_destroy
    portal1 = create_portal
    portal_sol_cat = portal1.portal_solution_categories.last
    CentralPublisher::Worker.jobs.clear
    portal1.destroy
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'portal_solution_category_destroy', job['args'][0]
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_portal_solution_category_destroy(portal_sol_cat))
  end
end

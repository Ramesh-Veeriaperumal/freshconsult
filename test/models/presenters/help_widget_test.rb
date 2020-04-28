require_relative '../test_helper'
class HelpWidgetTest < ActiveSupport::TestCase
  include HelpWidgetTestHelper

  def setup
    super
    @account = @account.make_current
    CentralPublisher::Worker.jobs.clear
  end

  def teardown
    CentralPublisher::Worker.jobs.clear
  end

  def test_create_help_widget_central_publish
    widget = create_widget
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'help_widget_create', job['args'].first
    payload = widget.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_help_widget_pattern(widget))
  ensure
    widget.destroy
  end

  def test_update_settings_not_trigger_central_publish
    widget = create_widget
    CentralPublisher::Worker.jobs.clear
    request_params = {
      settings: {
        appearance: {
          'theme_color' => '#0f50d5',
          'button_color' => '#16193e'
        }
      }
    }
    widget.update_attributes(request_params)
    assert_equal CentralPublisher::Worker.jobs.size, 0
  ensure
    widget.destroy
  end

  def test_update_name_central_publish
    widget = create_widget
    old_name = widget.name
    CentralPublisher::Worker.jobs.clear
    request_params = {
      name: 'Changed widget name - Jidget'
    }
    widget.update_attributes(request_params)
    widget.reload
    job = CentralPublisher::Worker.jobs.last
    model_changes_from_central = job['args'].second['model_changes']
    model_changes = { 'name' => [old_name, widget.name] }
    assert_equal model_changes, model_changes_from_central
    payload = widget.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_help_widget_pattern(widget))
  ensure
    widget.destroy
  end

  def test_update_product_id_central_publish
    widget = create_widget(product_id: 1)
    old_product_id = widget.product_id
    CentralPublisher::Worker.jobs.clear
    request_params = {
      product_id: 2
    }
    widget.update_attributes(request_params)
    widget.reload
    job = CentralPublisher::Worker.jobs.last
    model_changes_from_central = job['args'].second['model_changes']
    model_changes = { 'product_id' => [old_product_id, widget.product_id] }
    assert_equal model_changes, model_changes_from_central
    payload = widget.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_help_widget_pattern(widget))
  ensure
    widget.destroy
  end

  def test_destroy_help_widget_central_publish
    widget = create_widget
    CentralPublisher::Worker.jobs.clear
    widget.destroy
    job = CentralPublisher::Worker.jobs.last
    model_properties = {
      'id': widget.id,
      'account_id': widget.account_id
    }.with_indifferent_access
    assert_equal 'help_widget_destroy', job['args'].first
    assert_equal model_properties, job['args'].second['model_properties']
  ensure
    widget.destroy
  end
end

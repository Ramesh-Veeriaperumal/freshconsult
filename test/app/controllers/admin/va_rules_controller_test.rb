# frozen_string_literal: true

require_relative '../../../api/test_helper'
class Admin::VaRulesControllerTest < ActionController::TestCase
  include AccountHelper

  def test_toggle_cascade_on_disable
    @account.enable_setting(:cascade_dispatcher)
    post :toggle_cascade
    @account.reload
    assert_equal(@account.cascade_dispatcher_enabled?, false)
  end

  def test_toggle_cascade_on_enable
    @account.disable_setting(:cascade_dispatcher)
    post :toggle_cascade
    @account.reload
    assert(@account.cascade_dispatcher_enabled?)
  end
end

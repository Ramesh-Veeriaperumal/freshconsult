# frozen_string_literal: true

require_relative '../../../api/test_helper'
class Admin::VaRulesControllerTest < ActionController::TestCase
  include AccountHelper

  def test_redirect_for_google_signin
    @account.enable_setting(:cascade_dispatcher)
    post :toggle_cascade, {:cascade_dispatcher=>"0","_"=>""}
    @account.reload
    assert(!@account.cascade_dispatcher_enabled?)
  end
    
  def test_redirect_for_microsoft_signin
    @account.disable_setting(:cascade_dispatcher)
    post :toggle_cascade, {:cascade_dispatcher=>"0","_"=>""}
    @account.reload
    assert(@account.cascade_dispatcher_enabled?)
  end
end
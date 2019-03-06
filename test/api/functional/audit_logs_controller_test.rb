require_relative '../test_helper'
class AuditLogsControllerTest < ActionController::TestCase

  def setup
    super
    initial_setup
    @account.add_feature :audit_logs_central_publish
  end

  def teardown
    @account.revoke_feature :audit_logs_central_publish
  end

  @@initial_setup_run = false

  def initial_setup
    @account ||= Account.first.make_current
    @@initial_setup_run = true
  end

  def test_audit_log_for_subscription_agent
    HyperTrail::AuditLog.any_instance.stubs(:fetch).returns(hypertrail_sample_response)
    post :filter, {version: 'private', format: 'json'}
    assert_response 200
    match_json audit_log_filter_response
    assert_equal response.api_meta[:next], next_url
    HyperTrail::AuditLog.any_instance.unstub(:fetch)
  end

  def test_audit_log_event_name
    get :event_name, {version: 'private', format: 'json', type: "dispatcher"}
    assert_response 200
    resp = @account.all_va_rules.map { |rule| { name: rule.name, id: rule.id } }
    match_json resp
  end

  def test_export_works
    skip
    HyperTrail::AuditLog.any_instance.stubs(:fetch_job_id).returns({:id => 1})
    HyperTrail::AuditLog.any_instance.expects(:trigger_export).returns(true)
    post :export, {version: 'private', format: 'json', from: 1.month.ago.to_s, to: Time.now.to_s}
    assert_response 200
  end

  private

  def audit_log_filter_response
    [{"time"=>1526981491586, "ip_address"=>"127. 0. 0. 1", "name"=>{"name"=>"2314211", "url_type"=>"agent", "id"=>74341}, "event_performer"=>{"id"=>37, "name"=>"Admin", "url_type"=>"agent"}, "action"=>"update", "event_type"=>"Agent", "description"=>[{"type"=>"default", "field"=>"Email", "value"=>{"from"=>"dslads@dsadasa.com", "to"=>"dsqslads@dsadasa.com"}}, {"type"=>"default", "field"=>"Ticket Permission", "value"=>{"from"=>"Global Access", "to"=>"Group Access"}}]}, {"time"=>1526980693092, "ip_address"=>nil, "name"=>{"name"=>"subscription", "url_type"=>"subscription", "id"=>6}, "event_performer"=>{"id"=>0, "name"=>"system", "url_type"=>"agent"}, "action"=>"update", "event_type"=>"Subscription", "description"=>[{"type"=>"default", "field"=>"Agent Limit", "value"=>{"from"=>10, "to"=>9}}, {"type"=>"default", "field"=>"Subscription State", "value"=>{"from"=>"active", "to"=>"trial"}}, {"type"=>"default", "field"=>"Renewal Period", "value"=>{"from"=>"Monthly", "to"=>"Quarterly"}}, {"type"=>"default", "field"=>"Card Number", "value"=>{"from"=>"************1111", "to"=>"dsadadasa"}}, {"type"=>"default", "field"=>"Card Expiration", "value"=>{"from"=>"12-2019", "to"=>"2018-08-30T09:16:07Z"}}, {"type"=>"default", "field"=>"Subscription Plan", "value"=>{"from"=>"Forest", "to"=>"Estate"}}, {"type"=>"default", "field"=>"Subscription Currency", "value"=>{"from"=>"EUR", "to"=>"INR"}}]}]
  end

  def hypertrail_sample_response
    {:links=>[{:rel=>"next", :href=>"http://hypertrail-dev.freshworksapi.com/api/v1/audit/account/shridartest1?nextToken=1600550144942760722", :type=>"GET"}], :data=>[{:actor=>{:name=>"Admin", :id=>37, :type=>"agent"}, :timestamp=>1526981491586, :changes=>{:name=>["nasldasda", "2314211"], :email=>["dslads@dsadasa.com", "dsqslads@dsadasa.com"], :ticket_permission=>[1, 2], :time_zone=>["Central Time (US & Canada)", "Arizona"], :scoreboard_level_id=>[1, 3]}, :object=>{:last_seen_at=>nil, :name=>"2314211", :failed_login_count=>0, :active_since=>nil, :blocked_at=>nil, :customer_id=>nil, :email=>"dsqslads@dsadasa.com", :last_active_at=>nil, :parent_id=>0, :description=>nil, :job_title=>"", :current_login_ip=>nil, :privileges=>"2596148429267413814265248181387263", :whitelisted=>false, :signature_html=>"<div dir=\"ltr\"><p><br></p>\n</div>", :twitter_id=>nil, :signature=>nil, :user_role=>nil, :ticket_permission=>2, :current_login_at=>nil, :user_id=>74341, :occasional=>false, :fb_profile_id=>nil, :google_viewer_id=>nil, :last_login_at=>nil, :points=>nil, :id=>54, :account_id=>6, :language=>"en", :second_email=>nil, :last_login_ip=>nil, :extn=>nil, :login_count=>0, :preferences=>{:agent_preferences=>{:shortcuts_mapping=>[], :falcon_ui=>false, :freshchat_token=>nil, :show_onBoarding=>true, :notification_timestamp=>nil, :shortcuts_enabled=>true}, :user_preferences=>{:was_agent=>false, :agent_deleted_forever=>false}}, :delta=>true, :external_id=>nil, :address=>nil, :available=>false, :blocked=>false, :created_at=>"2018-05-22T09:29:59Z", :import_id=>nil, :posts_count=>0, :helpdesk_agent=>true, :updated_at=>"2018-05-22T09:31:31Z", :mobile=>"", :deleted_at=>nil, :time_zone=>"Arizona", :scoreboard_level_id=>15, :deleted=>false, :phone=>"", :unique_external_id=>nil, :active=>false}, :account_id=>"shridartest1", :ip_address=>"127.0.0.1", :action=>"agent_update"}, {:actor=>{:name=>"system", :id=>0, :type=>"system"}, :timestamp=>1526980693092, :changes=>{:agent_limit=>[10, 9], :state=>["active", "trial"], :renewal_period=>[1, 3], :card_number=>["************1111", "dsadadasa"], :amount=>["620.0", "49.0"], :card_expiration=>["12-2019", "2018-08-30T09:16:07Z"], :updated_at=>["2018-05-15T22:54:24+05:30", "2018-05-22T14:48:12+05:30"], :subscription_plan_id=>[5, 4], :subscription_currency_id=>[1, 2]}, :object=>{:agent_limit=>9, :state=>"trial", :billing_id=>nil, :renewal_period=>3, :free_agents=>0, :card_number=>"dsadadasa", :amount=>49, :id=>6, :account_id=>6, :subscription_discount_id=>nil, :discount_expires_at=>nil, :created_at=>"2015-05-16T11:06:06Z", :subscription_affiliate_id=>nil, :card_expiration=>"2018-08-30 09:16:07", :updated_at=>"2018-05-22T09:18:12Z", :subscription_plan_id=>4, :subscription_currency_id=>2, :next_renewal_at=>"2018-06-15T17:24:18Z", :day_pass_amount=>3}, :account_id=>"shridartest1", :ip_address=>nil, :action=>"subscription_update"}]}
  end

  def next_url
    "http://hypertrail-dev.freshworksapi.com/api/v1/audit/account/shridartest1?nextToken=1600550144942760722"
  end
end

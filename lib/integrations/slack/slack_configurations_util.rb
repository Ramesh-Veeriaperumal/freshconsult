#Remove when slackv1 is obselete.
module Integrations::Slack::SlackConfigurationsUtil
  include Integrations::Slack::Constant

  def create_or_update_slack_rule
    channels = @installed_application.configs[:inputs]["channels"]
    channels.each do |channel|
      ticket_create_rule if channel["actions"].include? TICKET_CREATE
      ticket_update_rule if channel["actions"].include? STATUS_UPDATE
      note_create_rule if channel["actions"].include? NOTE_CREATE
    end
  end

  def note_create_rule
    note_action  = current_account.api_webhook_rules.build(:name => "slack_note", :description => "This rule posts data to slack when note is added", 
      :match_type => "all", :filter_data => { :performer => {"type" => ApiWebhooksController::PERFORMER_ANYONE }, 
      :events => [{ :name => "note_action",:value => "create" }], :conditions => params[:condition_data] || [] }, 
      :action_data => [{:name => "Integrations::Slack::SlackUtil", :value => "post_to_slack_on_note_create", :action => "note_create"}],
      :active => 1)
    note_action.save
  end


  def ticket_update_rule
    slack_update = current_account.account_va_rules.build(:name => "slack_update", :description => "This rule posts data to slack on ticket update", 
      :match_type => "all", :filter_data => [{ :name => "any", :operator => "is", :value => "any", :action_performed =>
        {:entity=>"Helpdesk::Ticket", :action => :update_status} } ],
        :action_data => [{:name => "Integrations::Slack::SlackUtil", :value => "post_to_slack_on_ticket_update", :action => "status_update"}], 
        :rule_type => VAConfig::INSTALLED_APP_BUSINESS_RULE, :active => 1)
    slack_update.save
  end

  def ticket_create_rule
    slack_create = current_account.api_webhook_rules.build(:name => "slack_create", :description => "This rule posts data to slack on ticket create", 
      :match_type => "all", :filter_data => { :performer => {"type" => ApiWebhooksController::PERFORMER_ANYONE }, 
      :events => [{ :name => "ticket_action",:value => "create" }], :conditions => params[:condition_data] || []  }, 
      :action_data => [{:name => "Integrations::Slack::SlackUtil", :value => "post_to_slack_on_ticket_create", :action => "ticket_create"}], 
      :active => 1)
    slack_create.save
  end

  def destroy_all_slack_rule
    current_account.account_va_rules.slack_destroy.destroy_all
  end

  def validate_configs
    slack_channel_id = @channels.collect { |channel| channel["id"] }
    @installed_application.configs[:inputs]["channels"].reject! { |channel| !slack_channel_id.include? channel["channel_id"] or !(channel["actions"].split(",") - FD_ACTIONS ).empty? }
    @installed_application.configs[:inputs]["channels"].uniq!
  end

  def channel_json
    application_id = Integrations::Application.find_by_name("slack").id
    app_obj =  current_account.installed_applications.find_by_application_id(application_id)
    token = app_obj.configs[:inputs]["oauth_token"]
    channel_url =  "#{SLACK_REST_API[:channel_list]}token=#{token}"
    response  = make_api_call(channel_url)
  end

  def channel_name
    json_channel = JSON.parse(channel_json[:text])["channels"]
    channels = []

    json_channel.each do |channel|
      channels << {
        "name" => "##{channel["name"]}",
        "id"   => channel["id"]
      }
    end
    channels.reverse!
  end

  def make_api_call(url)
    hrp = HttpRequestProxy.new
    params = { :domain => url }
    requestParams = { :method => "get"}
    response = hrp.fetch_using_req_params(params, requestParams)
  end

  def response_handle(url)
    response = make_api_call(url)[:text]
    response = JSON.parse(response)
  end
end
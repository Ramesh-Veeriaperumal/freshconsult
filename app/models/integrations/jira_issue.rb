require 'rubygems'
require 'jira4r'
require 'json'

class Integrations::JiraIssue
  include Integrations::AppsUtil
  def initialize(installed_app)
    @http_request_proxy = HttpRequestProxy.new
    @installed_app = installed_app unless installed_app.blank?
  end

  def create(params, request)
    method = "post"
    rest_url = "rest/api/2/issue"
    body = params[:body]
    fieldData = construct_params_for_http(method,rest_url,body)
    res_data = make_rest_call(fieldData, request)
    res_json = JSON.parse(res_data[:text])
    if res_json["key"]
      params[:remote_key] = res_json["key"]
      update(params,request)
    else
      res_json
    end
  end

  def delete(params,request)
    res_data = make_rest_call(params, request)
  end

  def update(params, request)
    custom_field_id = customFieldChecker(request)
    if(custom_field_id)
      req_data ={
        :update => {
          custom_field_id => [{
                                :set => params[:ticket_data]
          }]
        }
      }
      params[:rest_url] = "rest/api/2/issue/" + params[:remote_key]
      params[:method] = "put"
    else
      req_data = {
        :body => params[:ticket_data]
      }
      params[:rest_url] = "rest/api/2/issue/" + params[:remote_key] + "/comment"
      params[:method] = "post"
    end
    params[:body] = req_data.to_json
    res_data = make_rest_call(params, request)
    if(res_data[:status] == 400 && custom_field_id && JSON.parse(res_data[:text])["errors"][custom_field_id])
      delete_custom_field
      update(params,request)
    end
    res_data
  end

  def delete_custom_field
    @installed_app[:configs][:inputs]['customFieldId'] = nil
    @installed_app.save!
  end

  def authenticate(params,request=nil)
    make_rest_call(params,request);
  end

  def get_all_mandatory_fields_for_project_and_issuetype(params,request)
    res_data = make_rest_call(params,request)
    res_json = JSON.parse(res_data)
    mandatory_fields = {}
    res_json["projects"].first["issuetypes"].first["fields"].each do |field_key,field_value|
      if ((field_value["required"] && (field_key != "issuetype" && field_key != "project"))||(field_value["name"] == "Freshdesk Tickets"))
        mandatory_fields["field_key"] = field_value
      else
        next
      end
    end
    mandatory_fields
  end

  def fetch_jira_projects(request)
    params_project = construct_params_for_http("get","rest/api/2/project")
    res_project_json = JSON.parse(make_rest_call(params_project,request)[:text])
  end

  def fetch_jira_issues(request)
    params_issue = construct_params_for_http("get","rest/api/2/issuetype")
    res_issue_json = JSON.parse(make_rest_call(params_issue,request)[:text])
  end

  def add_comment(issueId, ticketData)
    req_data = {
        :body => ticketData
      }
      comment_data = construct_params_for_http("post","rest/api/2/issue/" + issueId + "/comment")
      comment_data[:body] = req_data.to_json
    make_rest_call(comment_data, nil)
  end

  def update_status(issue_id, new_status)
      ava_actions = get_available_status(issue_id)
      Rails.logger.debug "AvailableActions for #{issue_id}: #{ava_actions.inspect}"
      ava_actions["transitions"].each { |action|
        return progress_work_flow_action(issue_id, action["id"]) if (action["name"] == new_status)
      }
      Rails.logger.error "JIRA Issue not updated for #{issue_id}.  #{new_status} is not a valid status."
  end

  def get_available_status(issue_id)
    ava_actions_data = construct_params_for_http("get","rest/api/2/issue/"+issue_id+"/transitions?transitionId")
    JSON.parse(make_rest_call(ava_actions_data, nil)[:text])
  end

  def progress_work_flow_action(issue_id, action)
    req_data = {
      "transition" => {
        "id" => action
      }
    }
    progress_work_flow_data = construct_params_for_http("post",("rest/api/2/issue/"+issue_id+"/transitions?expand=transitions.fields"))
    progress_work_flow_data[:body] = req_data.to_json
    JSON.parse(make_rest_call(progress_work_flow_data, nil)[:text])
  end

  def register_webhooks(current_portal)
    req_data = {
          "name" => "Freshdesk webhook",
          "url"  =>  "https://"+current_portal.host+"/notify",
          "events" =>  [
              "jira:issue_created",
              "jira:issue_updated",
              "jira:issue_deleted",
              "jira:worklog_updated"
          ],
          "excludeIssueDetails" => true
        }
    webhook_data = construct_params_for_http("post","rest/webhooks/1.0/webhook")
    webhook_data[:body] = req_data.to_json
    make_rest_call(webhook_data, nil)
  end

  def delete_webhooks
  end
  
  private

  def getCustomFieldId(request)
    fieldData = construct_params_for_http("get","rest/api/2/field")
    customData=make_rest_call(fieldData,request)
    if (customData[:status]==200)
      customData = JSON.parse(customData[:text])
    else
      return
    end
    Rails.logger.debug "Received response for getting custom fields : #{customData.inspect}"
    customData.each do |customField|
      if(customField["name"] == "Freshdesk Tickets")
        return customField["id"]
      end
    end
    return
  end

  def customFieldChecker(request)
    if @installed_app.configs_customFieldId
      return @installed_app.configs_customFieldId
    else
      return populate_custom_field(request)
    end
  end

  def populate_custom_field(request)
    begin
      custom_field_id = getCustomFieldId(request)
    rescue Exception => e
      Rails.logger.error "Problem in fetching the custom field. \t#{e.message}"
    end
    unless custom_field_id.blank?
      @installed_app[:configs][:inputs]['customFieldId'] = custom_field_id
      @installed_app.save!
      return custom_field_id
    end
  end

end

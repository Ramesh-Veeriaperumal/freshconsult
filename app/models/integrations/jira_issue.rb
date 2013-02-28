require 'rubygems'
require 'jira4r'
require 'json'

class Integrations::JiraIssue

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

  private

  def construct_params_for_http(method,rest_url,body=nil)
    fieldData = {
      :username => @installed_app.configs_username,
      :password => @installed_app.configsdecrypt_password,
      :domain => @installed_app.configs_domain,
      :rest_url => rest_url,
      :method => method
    }
    if(body)
      fieldData[:body] = body
    end
    fieldData
  end
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

  def make_rest_call(params, request)
    @http_request_proxy.fetch(params, request)
  end
end

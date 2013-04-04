require 'rubygems'
require 'jira4r'
require 'json'

class Integrations::JiraIssue
  include Integrations::Jira::Api

  def initialize(installed_app)
    @http_request_proxy = HttpRequestProxy.new
    @installed_app = installed_app unless installed_app.blank?
  end

  def fetch_jira_projects_issues
    project_issue_hash = {
      :res_projects => [],
      :res_issues => []
    }
    http_parameter = construct_params_for_http(:projects)
    res_data = make_rest_call(http_parameter)
    project_issue_hash[:res_projects] = res_data[:json_data] unless (res_data[:exception])
    http_parameter = construct_params_for_http(:issuetypes)
    res_data = make_rest_call(http_parameter)
    project_issue_hash[:res_issues] = res_data[:json_data] unless (res_data[:exception])
    return project_issue_hash
  end

  def create(params)
    http_parameter = construct_params_for_http(:create)
    http_parameter[:body] = params[:body]
    res_data = make_rest_call(http_parameter)
    if(!res_data[:exception] && res_data[:json_data]  && res_data[:json_data]["key"])
      params['integrated_resource']={}
      params['integrated_resource']['remote_integratable_id'] = res_data[:json_data]["key"]
      params['integrated_resource']['account'] = @installed_app.account
      params['integrated_resource']['local_integratable_id'] = params[:local_integratable_id]
      params['integrated_resource']['local_integratable_type'] = params[:local_integratable_type]
      params[:remote_key] = params['integrated_resource']['remote_integratable_id']
      newIntegratedResource = Integrations::IntegratedResource.createResource(params)
      send_later(:update,params,{}) 
      return newIntegratedResource
    else
      return res_data
    end
  end

  def link_issue(params)
    res_data = update(params)
    unless(res_data[:exception])
      custom_field_id = @installed_app.configs[:inputs]['customFieldId']
      params['integrated_resource']={}
      params['integrated_resource']['remote_integratable_id'] = params[:remote_key]
      params['integrated_resource']['account'] = @installed_app.account
      params['integrated_resource']['local_integratable_id'] = params[:local_integratable_id]
      params['integrated_resource']['local_integratable_type'] = params[:local_integratable_type]
      newIntegratedResource = Integrations::IntegratedResource.createResource(params)
      newIntegratedResource["custom_field"]=custom_field_id unless custom_field_id.blank?
      return newIntegratedResource
    else
      res_data
    end
  end

  def unlink_issue(params)
    params['integrated_resource']={}
    params['integrated_resource']['id']=params[:id]
    params['integrated_resource']['account'] = @installed_app.account
    if @installed_app.configs_customFieldId
      res_data = update(params)
    end
    Integrations::IntegratedResource.deleteResource(params)
    return {:status=> :success}
  end

  #need to work on this
  def update(params, retry_flag = true)
    custom_field_id = customFieldChecker
    res_data = nil
    if(custom_field_id)
      req_data ={
        :update => {
          custom_field_id => [{
                                :set => params[:ticket_data]
          }]
        }
      }
      http_parameter = construct_params_for_http(:update,params[:remote_key])
      http_parameter[:body] = req_data.to_json
      res_data = make_rest_call(http_parameter)
    else
      return add_comment(params[:remote_key],params[:ticket_data])
    end  
    if(res_data && res_data[:exception] && custom_field_id && res_data[:json_data]["errors"][custom_field_id])
      if retry_flag
        res_data = update(params, false) 
      else
        return add_comment(params[:remote_key],params[:ticket_data])
      end
    end
    res_data
  end

  def add_comment(issueId, ticketData)
    req_data = {
        :body => ticketData
      }
      comment_data = construct_params_for_http(:comment,issueId)
      comment_data[:body] = req_data.to_json
      make_rest_call(comment_data, nil)
  end

  def delete(params)
    params['integrated_resource']={}
    params['integrated_resource']['remote_integratable_id'] = params[:remote_integratable_id]
    params['integrated_resource']['account'] = @installed_app.account
    http_parameter = construct_params_for_http(:delete_issue,params[:remote_integratable_id])
    res_data = make_rest_call(http_parameter)
    unless(res_data[:exception])
        status = Integrations::IntegratedResource.delete_resource_by_remote_integratable_id(params)
        return {:status=>status}
      else
        return res_data
    end
  end

  def delete_custom_field
    @installed_app[:configs][:inputs]['customFieldId'] = nil
    @installed_app.disable_observer = true
    @installed_app.save!
  end

  def authenticate
    body_content ={ :username => @installed_app.configs_username,
                    :password => @installed_app.configsdecrypt_password}.to_json
    jira_rest_api_auth = {
          :rest_url => "rest/auth/1/session",
          :domain => @installed_app.configs_domain,
          :method => "post",
          :body => body_content
    }
    make_rest_call(jira_rest_api_auth);
  end

  def update_status(issue_id, new_status)
      ava_actions = get_available_status(issue_id)
      Rails.logger.debug "AvailableActions for #{issue_id}: #{ava_actions.inspect}"
      ava_actions["transitions"].each { |action|
        return progress_work_flow_action(issue_id, action["id"]) if (action["name"] == new_status)
      } if ava_actions
      
      Rails.logger.error "JIRA Issue not updated for #{issue_id}.  #{new_status} is not a valid status."
  end

  def get_available_status(issue_id)
    ava_actions_data = construct_params_for_http(:get_transitions,issue_id)
    res_data = make_rest_call(ava_actions_data, nil)
    res_data[:exception] ? false : res_data[:json_data]
  end

  def progress_work_flow_action(issue_id, action)
    req_data = {
      "transition" => {
        "id" => action
      }
    }
    progress_work_flow_data = construct_params_for_http(:put_transitions,issue_id)
    progress_work_flow_data[:body] = req_data.to_json
    make_rest_call(progress_work_flow_data, nil)
  end

  private

  def getCustomFieldId
    fieldData = construct_params_for_http(:custom_field_details)
    customData=make_rest_call(fieldData)
    unless (customData[:exception])
      customData[:json_data].each do |customField|
        if(customField["name"] == "Freshdesk Tickets")
          return customField["id"]
        end
      end
    end
    return false
  end

  def customFieldChecker
    if @installed_app.configs_customFieldId
      return @installed_app.configs_customFieldId
    else
      return populate_custom_field
    end
  end

  def populate_custom_field
    begin
      custom_field_id = getCustomFieldId
    rescue Exception => e
      Rails.logger.error "Problem in fetching the custom field. \t#{e.message}"
    end
    if custom_field_id
      @installed_app[:configs][:inputs]['customFieldId'] = custom_field_id
      @installed_app.disable_observer = true
      @installed_app.save!
      return custom_field_id
    end
  end

end

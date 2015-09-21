require 'rubygems'
require 'jira4r'
require 'json'
require 'open-uri'
require 'net/http/post/multipart'

class Integrations::JiraIssue
  include Integrations::Jira::Api
  include Redis::RedisKeys
  include Redis::IntegrationsRedis
  include Integrations::Jira::Helper

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
      params[:operation] = "update"
      params[:app_id] = @installed_app.id
      Resque.enqueue(Workers::Integrations::JiraAccountUpdates,params)
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
      params[:operation] = "link_issue"
      params[:app_id] = @installed_app.id
      Resque.enqueue(Workers::Integrations::JiraAccountUpdates,params)
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
    customField_args = customFieldChecker
    res_data = nil
    custom_field_id = customField_args[:customFieldId]
    custom_field_data = customField_args[:customFieldName] == "Freshdesk Tickets" ? params[:ticket_data] : params[:ticket_url]
    if(custom_field_id)
      req_data ={
        :update => {
          custom_field_id => [{
                                :set => custom_field_data
          }]
        }
      }
      if params[:cloud_attachment]
       req_data[:fields] = {}
       req_data[:fields][:description] = params[:cloud_attachment]
      end
      http_parameter = construct_params_for_http(:update,params[:remote_key])
      http_parameter[:body] = req_data.to_json
      res_data = make_rest_call(http_parameter)
    else
      return add_comment(params[:remote_key],params[:ticket_data])
    end  
    if(res_data && res_data[:exception] && custom_field_id)
      delete_custom_field
      if retry_flag
        res_data = update(params, false) 
      else
        return add_comment(params[:remote_key],params[:ticket_data])
      end
    end
    res_data
  end

  def construct_attachment_params(issue_id, obj)
    unless obj.attachments.empty?
      request_params = construct_params_for_http(:add_attachment, issue_id)
      url = URI.parse("#{request_params[:domain]}/#{request_params[:rest_url]}")
      add_attachment(request_params, url, obj.attachments) 
    end
  end

  def add_attachment(request_params, url, attachments)
    attachments.each do |attachment|
      attachment_url = AwsWrapper::S3Object.url_for(attachment.content.path,attachment.content.bucket_name,:expires => 300.seconds, :secure => true, :response_content_type => attachment.content_content_type)
      begin
      web_contents = open(attachment_url)
      rescue Timeout::Error
        Rails.logger.debug "Timeout::Error: #{params}\n"
        next
      rescue
        Rails.logger.debug "Connection failed: #{params}\n"
        next
      end
      req = Net::HTTP::Post::Multipart.new url.path, "file" => UploadIO.new(web_contents, attachment.content_content_type, attachment.content_file_name)
      
      req["X-Atlassian-Token"] = 'nocheck'
      
      req.basic_auth request_params[:username], request_params[:password]
      http = Net::HTTP.new(url.host, url.port)
      begin
      res = Net::HTTP.start(url.host, url.port,:use_ssl => url.scheme == 'https') do |http|
         http.request(req)
      end
      rescue Timeout::Error
        Rails.logger.debug "Timeout::Error: #{params}\n and Attachment Response body: #{res.body}"
      rescue
        Rails.logger.debug "  Attachment Response body: #{res.body}"
      end
    end
  end

  def push_existing_notes_to_jira(issue_id, tkt_obj)
    obj_mapper = Integrations::ObjectMapper.new
    tkt_obj.notes.each do |note| 
      unless note.meta?
        mapped_data = obj_mapper.map_it(Account.current.id, "add_comment_in_jira" , note, :ours_to_theirs, [:map])
        response = add_comment(issue_id, mapped_data)
        jira_key = INTEGRATIONS_JIRA_NOTIFICATION % {:account_id=> Account.current.id, :local_integratable_id=> tkt_obj.id, :remote_integratable_id=> issue_id, :comment_id => response[:json_data]["id"] }
        set_integ_redis_key(jira_key, "true", 240)
        construct_attachment_params(issue_id, note) unless exclude_attachment?(@installed_app)
      end
    end
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

  def getCustomFieldDetails
    fieldData = construct_params_for_http(:custom_field_details)
    customData=make_rest_call(fieldData)
    unless (customData[:exception])
      customData[:json_data].each do |customField|
        if(customField["name"] == "Freshdesk Tickets" || customField["name"] == "Freshdesk Public Tickets")
          return {:customFieldId => customField["id"],:customFieldName => customField["name"]}
        end
      end
    end
    return {}
  end

  def customFieldChecker
    if @installed_app.configs_customFieldId
      customField_args = {
          :customFieldId => @installed_app.configs_customFieldId,
          :customFieldName => @installed_app.configs_customFieldName
      }
      return customField_args
    else
      return populate_custom_field
    end
  end

  def populate_custom_field
    begin
      custom_field_args = getCustomFieldDetails
    rescue Exception => e
      Rails.logger.error "Problem in fetching the custom field. \t#{e.message}"
    end
    if !custom_field_args.empty? and custom_field_args[:customFieldId]
      @installed_app[:configs][:inputs]['customFieldId'] = custom_field_args[:customFieldId]
      @installed_app[:configs][:inputs]['customFieldName'] = custom_field_args[:customFieldName]
      @installed_app.disable_observer = true
      @installed_app.save!
    end
    return custom_field_args;
  end
end

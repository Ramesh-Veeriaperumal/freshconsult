# encoding: utf-8
module Integrations::Jira::Api

JIRA_REST_API = {
    :create => {
      :method => "post",
      :rest_url => "rest/api/latest/issue",
      :content_type => "application/json"
    },
    :comment => {
      :method => "post",
      :rest_url => "rest/api/latest/issue/issueId/comment",
      :content_type => "application/json"
    },
    :update => {
      :method => "put",
      :rest_url => "rest/api/latest/issue/issueId",
      :content_type => "application/json"
    },
    :projects => {
      :method => "get",
      :rest_url => "rest/api/latest/project",
      :content_type => "application/json"
    },
    :issuetypes => {
      :method => "get",
      :rest_url => "rest/api/latest/issuetype",
      :content_type => "application/json"
    },
    :custom_field_details => {
      :method => "get",
      :rest_url => "rest/api/latest/field",
      :content_type => "application/json"
    },
    :put_transitions => {
      :method => "post",
      :rest_url => "rest/api/latest/issue/issueId/transitions?expand=transitions.fields",
      :content_type => "application/json"
    },
    :get_transitions => {
      :method => "get",
      :rest_url => "rest/api/latest/issue/issueId/transitions?transitionId",
      :content_type => "application/json"
    },
    :delete_issue => {
      :method => "delete",
      :rest_url => "rest/api/latest/issue/issueId",
      :content_type => "application/json"
    },
    :register_webhooks => {
      :method => "post",
      :rest_url => "rest/webhooks/1.0/webhook",
      :content_type => "application/json"
    },
    :available_webhooks => {
      :method =>"get",
      :rest_url =>"rest/webhooks/1.0/webhook",
      :content_type => "application/json"
    },
    :delete_webhooks => {
      :method => "delete",
      :rest_url => "rest/webhooks/1.0/webhook/issueId",
      :content_type => "application/json"
    }
  } 

  def construct_params_for_http(method, issueId = nil)
    rest_url = issueId ? JIRA_REST_API[method][:rest_url].gsub("issueId",issueId) : JIRA_REST_API[method][:rest_url]
    fieldData = {
      :username => @installed_app.configs_username,
      :password => @installed_app.configsdecrypt_password,
      :domain => @installed_app.configs_domain,
      :rest_url => rest_url,
      :method => JIRA_REST_API[method][:method],
      :content_type => JIRA_REST_API[method][:content_type] 
    }
  end

  def make_rest_call(params,request = nil)
    res_data = @http_request_proxy.fetch(params,request)
    handle_jira_response(res_data)
  end

  def handle_jira_response(res_data)
    begin
      jira_data = {
        :exception => true,
        :error => "Exception: Cannot process your request",
        :json_data => ""
      }
      if (res_data[:status] == 200 || res_data[:status] == 201 || res_data[:status] == 204)
        jira_data[:exception] = false 
        jira_data[:error] = ""
        jira_data[:json_data] = JSON.parse(res_data[:text]) if (res_data[:text])
      else
        error_data =  JSON.parse(res_data[:text]) if (res_data[:text])
        if(error_data && error_data["errorMessages"])
            errorText = "Exception:"+error_data["errorMessages"].join(",") 
            errorText = "Exception:"+error_data["errors"].values.join(",") if (error_data["errors"] && !error_data["errors"].empty?)      
            jira_data[:error] = errorText 
            jira_data[:json_data] = error_data
            Rails.logger.error "#{errorText.inspect} #{res_data.inspect}"
        end
      end
      return jira_data
    rescue Exception => e
      jira_data[:exception] = true
      jira_data[:error] = "Exception: Cannot process your request"
      Rails.logger.error "Exception: Cannot process your request. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      return jira_data
    end    
  end
  
end
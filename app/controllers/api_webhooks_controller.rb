class ApiWebhooksController < ApplicationController

  include ApiWebhooks::Constants
  include Va::Webhook::Constants
  include ApiWebhooks::PlaceholderMethods

  rescue_from ArgumentError, :with => :error_handler

  attr_accessor :va_rule

  def create
    initialize_subscribe
    if va_rule.save
      result = {:id => va_rule.id, :message => "success", 
                :http_code => Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]}
    else
      result = {:message => "error", 
                :http_code => Rack::Utils::SYMBOL_TO_STATUS_CODE[:conflict]}
    end
    api_responder(result)
  end

  def destroy
    vr = subscribe_scoper.find(params[:id]).destroy
    if vr.destroyed?
      result = {:message => "success", :http_code => Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]}
    else
      result = {:message => "error", :http_code => Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request]}
    end
    api_responder(result)
  end


  private

    def initialize_subscribe
      check_rule_type_exists?
      @va_rule = current_account.va_rules.new
      va_rule.action_data = action_data_builder
      va_rule.filter_data = filter_data_builder
      va_rule.match_type = "all"
      va_rule.name = params[:name]
      va_rule.description = params[:description] 
      va_rule.active = true
      va_rule.rule_type = VAConfig::API_WEBHOOK_RULE
    end

    def subscribe_scoper
      current_account.api_webhook_rules
    end

    def check_rule_type_exists?
      throw_error if WHITELISTED_DOMAIN.exclude?(URI.parse(params["url"]).host)
      current_account.api_webhooks_rules_from_cache.each do |va|
        throw_error(va["id"]) if va.action_data.first[:url] == params["url"] && 
                                va.filter_data[:events].first["name"] == params["event_data"].first["name"] && 
                                va.filter_data[:events].first["value"] == params["event_data"].first["value"]
      end
    end

    def action_data_builder
      url = params[:url]
      username = params[:username]
      password = params[:password]
      api_key = params[:api_key]
      field_attr = map_fields
      field_params = Hash[field_attr.map { |i| [i[1], i[0]] }]
      request_type = REQUEST_TYPE.key('post')
      content_layout = SIMPLE_WEBHOOK
      content_type = xml_request? ? CONTENT_TYPE.key('text/xml') : CONTENT_TYPE.key('application/json')
      if username.present? 
        data = [ :name => "trigger_webhook", :request_type => request_type, :url => url, 
                 :content_type => content_type, :content_layout => content_layout, 
                 :params => field_params,  :need_authentication => true, :username => username, 
                 :password => password ]
      elsif api_key.present?
        data = [:name => "trigger_webhook", :request_type => request_type, :url => url, 
                :content_type => content_type, :content_layout => content_layout, 
                :params => field_params,:need_authentication => true, :api_key => api_key ]
      else
        data = [:name => "trigger_webhook", :request_type => request_type, :url => url, 
                :content_type => content_type, :content_layout => content_layout, 
                :params => field_params ]
      end              
      data
    end

    def xml_request?
      (request.url.include? ".xml") ? true : false
    end

    def filter_data_builder
      filter_data = {
        :performer => {"type" => PERFORMER_ANYONE},
        :events => params[:event_data].blank? ? [] : params[:event_data],
        :conditions => params[:condition_data].blank? ? [] : params[:condition_data],
      }
      va_rule.filter_data = filter_data.blank? ? [] : filter_data
    end

    def map_fields
      event_action = params[:event_data]
      throw_error if event_action.blank? || !["create","update"].include?(event_action.first["value"])
      case event_action.first["name"].to_sym
        when :ticket_action
          ticket_placeholder
        when :note_action
          note_placeholder
        when :user_action
          user_placeholder
        else 
          throw_error
      end
    end

    def api_responder(respond_hash)
      status = respond_hash[:http_code]
      respond_to do |format|
        format.json{
          render :json => respond_hash, :status => status
        }
        format.xml {
          render :xml => respond_hash.to_xml(:root => :message, :dasherize => false, 
                                             :skip_instruct => true,), :status => status
        }
      end
    end

    def error_handler(exception)
      result = {:message=> exception.message, :http_code => 422, :error_code => "Unprocessable Entity"}
      respond_to do |format|
        format.xml {
          render :xml => result.to_xml(:root => :error_details, :skip_instruct => true, 
                                       :dasherize => false),:status => :unprocessable_entity
        }
        format.json {
          render :json => {:error_details => result}, :status => :unprocessable_entity
        }
      end
    end

    def throw_error(id=nil)
      raise ArgumentError, "Similar webhooks with id #{id} already exists for this url" unless id.nil?
      raise ArgumentError, "Invalid argument"
    end
end
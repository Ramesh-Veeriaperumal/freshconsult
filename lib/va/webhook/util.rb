module Va::Webhook::Util

  include Va::Webhook::Constants
  include Va::Util
  
	private

    def generate_auth_header
      username = act_hash[:username] || act_hash[:api_key]
      password = decrypt(act_hash[:password].to_s)
      act_hash[:need_authentication] ? 
        { :auth_header => "Basic #{Base64.encode64("#{username}:#{password}").delete("\r\n")}"} : {}
      #Use Base64.strict_encode64 in ruby 1.9.3
    end

    def generate_params act_on, content_type
      {
        :domain       => substitute_placeholders_in_format(act_on, :url, URL_ENCODED),
        :encode_url   => false,
        :ssl_enabled  => :false,
        :method       => REQUEST_TYPE[act_hash[:request_type].to_i],
        :content_type => CONTENT_TYPE[content_type],
        :timeout      => 15
      }
    end

    def decrypt password
      return 'X' if password.empty? #Password shouldn't be empty for API keys
      private_key = OpenSSL::PKey::RSA.new(File.read("config/cert/private.pem"), "freshprivate")
      private_key.private_decrypt(Base64.decode64(password))
    end

    def generate_body_from_hash act_on, content_type
      unless act_hash[:params].nil? 
        act_hash[:params] = substitute_placeholders_in_format(act_on, :params)
        construct_webhook_body content_type, act_hash[:params], :freshdesk_webhook
      end
    end

    def substitute_placeholders_in_format act_on, content_key, content_type = nil
      event_hash  = get_matched_event_hash(triggered_event)
      content     = act_hash[content_key]
      contexts    = { map_class(act_on.class.name) => act_on, 'helpdesk_name' => act_on.account.portal_name, 
        'event_performer' => doer, 'triggered_event' => j(event_hash.to_json) }
      filters     = { :filters => [Va::Webhook::HelperMethods] }
      case content
      when String
        Liquid::TemplateInFormat.parse(content.to_s, content_type).render(contexts, filters)
      when Hash
        Liquid::TemplateInFormat.parse_hash(content, content_type).render_hash(contexts, filters)
      end
    end

    def get_matched_event_hash event
      event_name = event.keys.first
      event_change = event[event_name]
      return { event_name => event_change } unless event_change.is_a? Array
      { event_name => { :from => event_change[0], :to => event_change[1] } }
    end

    def construct_webhook_body content_type, params_hash, root_node
      case content_type
      when XML
        return params_hash.to_xml :root => root_node 
      when JAVASCRIPT_OBJECT_NOTATION
        return { root_node => params_hash }.to_json
      when URL_ENCODED
        return { root_node => params_hash}.to_query
      end
    end

end
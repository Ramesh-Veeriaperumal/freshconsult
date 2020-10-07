#This class is responsible for communication with facebook
# * builds the authorization url
# * create's facebook page objects (Social::FacebookPage)
# * updates facebook page token if any page tab is added
module Facebook
  module Oauth
    class FbClient
      
      include Facebook::Constants
      include Facebook::Oauth::Constants
      include Facebook::Exception::Handler
      include Redis::OthersRedis
      include Facebook::GatewayJwt
      include Admin::Social::FacebookGatewayHelper

      attr_accessor :fb_app_id, :call_back_url, :oauth,:account_url

      # call_back_url is the url where facebook would redirect back with code after it authorizes
      def initialize(call_back_url, page_tab = false,account_url = nil)
        @call_back_url = call_back_url
        @account_url   = account_url
        @fb_app_id, secret_key = Facebook::Tokens.new(page_tab).tokens.values
        @oauth = Koala::Facebook::OAuth.new(@fb_app_id, secret_key, @call_back_url)
      end
      
      # Returns the complete url the client should hit inorder to authorize with Facebook
      # params[state] is the session state object
      def authorize_url(state, page_tab = false)
        if page_tab
          permissions = Facebook::Oauth::Constants::PAGE_TAB_PERMISSIONS.join(',')
          url = Facebook::Oauth::Constants::PAGE_TAB_URL
        else
          fb_permissions = Facebook::Oauth::Constants::PAGE_PERMISSIONS
          permissions = fb_permissions.join(',')
          url = Facebook::Oauth::Constants::FB_AUTH_DIALOG_URL
        end
        set_others_redis_key(state, "#{@account_url}", 180) if @account_url
        "#{url}?client_id=#{self.fb_app_id}&redirect_uri=#{self.call_back_url}&state=#{state}&scope=#{permissions}"
      end
      
      # Gets the access token and page token once code is passed
      def auth(code)
        access_token code
        gateway_facebook = {
          gateway_facebook_url: gateway_facebook_url,
          gateway_facebook_route: gateway_facebook_route,
          create_payload_option: create_payload_option,
          authorization_token: authorization_token
        }
        REALTIME_BLOCK.call(fetch_facebook_pages, @oauth_access_token, gateway_facebook)
      end

      def generate_url(offset)
        "#{FACEBOOK_GRAPH_URL}/#{GRAPH_API_VERSION}/me/accounts?access_token=#{@oauth_access_token}&limit=#{LIMIT_PER_REQUEST}&offset=#{offset}"
      end

      def fetch_facebook_pages
        pages = []  
        offset = 0
        loop do 
          response = JSON.parse(RestClient.get(generate_url(offset), {:accept => :json}))
          pages += response['data']
          break if response['paging'].nil? || response['paging']['next'].nil? 
          offset += response['data'].length
        end
        pages.select{|p| !p["category"].eql?("Application")}
      end

      def access_token code
        client_id, client_secret = Facebook::Tokens.new(false).tokens.values
        query_params = ACCESS_TOKEN_PARAMS % {:client_id => client_id, :client_secret => client_secret, :redirect_uri => call_back_url, :code => code}
        access_token_request = "#{FACEBOOK_GRAPH_URL}/#{GRAPH_API_VERSION}/#{ACCESS_TOKEN_PATH}?#{query_params}"
        message = RestClient.get access_token_request, {:accept => :json}
        message = JSON.parse(message)
        if message.nil? || message["access_token"].blank?
          Rails.logger.debug "Error while adding facebook page in account #{Account.current} with response #{message}" 
        else
          @oauth_access_token = message["access_token"]
        end
      end
      
      def page_tab_add(tabs_added)
        PAGE_TAB_BLOCK.call(tabs_added)
      end
      
      REALTIME_BLOCK = Proc.new { |pages, oauth_access_token, gateway_facebook|
        graph        = Koala::Facebook::API.new(oauth_access_token)
        profile      = graph.get_object("me")
        fb_pages     = Array.new
        page_ids     = []
        pages.each { |page| page_ids.push(page['id'].to_s) }
        pages_info = {}
        page_ids.each_slice(50) do |page_ids_sub_list|
          pages_info.merge!(graph.get_objects(page_ids_sub_list, fields: PAGE_FIELDS))
        end
        fd_linked_pages = Hash.new []

        if page_ids.present?
          begin
            request_params = { method: 'post', auth_header: gateway_facebook[:authorization_token] }
            params = {
              domain: gateway_facebook[:gateway_facebook_url],
              rest_url: "#{gateway_facebook[:gateway_facebook_route]}/bulk_fetch",
              body: {
                facebookPageIds: page_ids
              }.to_json
            }
            response = HttpRequestProxy.new.fetch_using_req_params(params, request_params, gateway_facebook[:create_payload_option])
            response_text = JSON.parse response[:text]
            fd_linked_pages.merge!(response_text.try(:[], 'pages') ? response_text['pages'] : {})
            Rails.logger.info("Gateway Bulk Fetch for Facebook, Account:: #{Account.current.id}, response status::#{response[:status]}")
          rescue StandardError => e
            Rails.logger.error("An Exception occured while getting bulk page details from Gateway for account::#{Account.current.id}, \n
              message::#{e.message}, backtrace::#{e.backtrace.join('\n')}")
          end
        end
        pages.each do |page|
          page.symbolize_keys!
          page_id = page[:id]
          limit_reached = false
          # Check if Facebook Page is already assossiated with an account
          unless Account.current.facebook_pages.find_by_page_id(page[:id])
            total_accounts_count = fd_linked_pages[page_id].length
            all_domains = DomainMapping.domain_names(fd_linked_pages[page_id])
            source_string = all_domains.join(', ') unless all_domains.empty?
            other_pods_count = total_accounts_count - all_domains.length
            source_string.concat(" +#{other_pods_count} more #{'account'.pluralize(other_pods_count)}") if source_string.present? && other_pods_count > 0

            # In case, the page has already been added to 10 accounts,
            # we set the page_id to nil and send the page object to frontend for page association
            # In case the user tries to associate this page, it will fail as this page object will
            # not have page_id present
            if total_accounts_count >= FacebookGatewayConfig['max_page_limit']
              limit_reached = true
              page_id = nil
            end
          end
          page_info = pages_info[page[:id].to_s].presence || graph.get_object(page[:id], fields: PAGE_FIELDS)
          page_info = page_info.deep_symbolize_keys
          fb_pages << {
            :profile_id      => profile["id"] ,
            :access_token    => oauth_access_token,
            :page_id         => page_id,
            :page_name       => page_info[:name],
            :page_token      => page[:access_token],
            :page_img_url    => page_info[:picture][:data][:url] || DEFAULT_PAGE_IMG_URL,
            :page_link       => page_info[:link] ,
            :fetch_since     => 0,
            :reauth_required => false,
            :source          => source_string,
            :last_error      => nil,
            :message_since   => (Time.now - 1.week).utc.to_i,
            :enable_page     => true,
            realtime_messaging: Account.current.fb_msg_realtime_enabled? ? 1 : 0,
            :limit_reached => limit_reached
          } unless page[:access_token].blank?
        end
        fb_pages
      }
      
      PAGE_TAB_BLOCK = Proc.new{ |tabs_added|
        if Account.current
          page_ids  = tabs_added.keys
          page_tabs = Account.current.facebook_pages.where(page_id: page_ids).to_a
          @edit_tab = true unless page_tabs.blank?
          page_tabs.each do |page_tab|
            page_tab.update_attribute(:page_token_tab, page_tab.page_id) if tabs_added[page_tab.page_id.to_s]
          end
        end
      }

      def profile_name(profile_id, fan_page)
        _error_msg, user, _code = sandbox do
          @fan_page = fan_page
          rest = Koala::Facebook::API.new(fan_page.access_token)
          rest.get_object(profile_id,{:fields => PROFILE_NAME_FIELDS}).symbolize_keys
        end
        if ERRORS.include?(user)
          ""
        else
          "#{user[:first_name]} #{user[:last_name]}"
        end
      end

    end
  end
end

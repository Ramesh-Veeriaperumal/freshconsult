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
          permissions = Facebook::Oauth::Constants::PAGE_PERMISSIONS.join(',')
          url = Facebook::Oauth::Constants::FB_AUTH_DIALOG_URL
        end
        set_others_redis_key(state, "#{@account_url}", 180) if @account_url
        "#{url}?client_id=#{self.fb_app_id}&redirect_uri=#{self.call_back_url}&state=#{state}&scope=#{permissions}"
      end
      
      # Gets the access token and page token once code is passed
      def auth(code)
        access_token code
        REALTIME_BLOCK.call(fetch_facebook_pages, @oauth_access_token)
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
      
      REALTIME_BLOCK = Proc.new { |pages, oauth_access_token|
        graph        = Koala::Facebook::API.new(oauth_access_token)
        profile      = graph.get_object("me")
        fb_pages     = Array.new
        pages.each do |page|
          page.symbolize_keys!
          page_id = page[:id]
          
          #Check if Facebook Page is already assossiated with an account
          unless Account.current.facebook_pages.find_by_page_id(page[:id])
            page_source = Social::FacebookPageMapping.find_by_facebook_page_id(page[:id])
            Rails.logger.debug('From RT block')
            if page_source
              source_account = page_source.shard.domains.main_portal.first
              if source_account
                source_string = "#{source_account.domain}"
                page_id = nil
              end
              Rails.logger.debug "Linked FB page info :: #{Account.current.id} :: #{page[:access_token]} :: #{page[:id]} :: #{source_account}" 
            end
          end
          
          page_info    = graph.get_object(page[:id], :fields => PAGE_FIELDS)
          page_info    = page_info.deep_symbolize_keys
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
            :realtime_messaging => Account.current.launched?(:fb_msg_realtime) ? 1 : 0
          } unless page[:access_token].blank?
        end
        fb_pages
      }
      
      PAGE_TAB_BLOCK = Proc.new{ |tabs_added|
        if Account.current
          page_ids  = tabs_added.keys
          page_tabs = Account.current.facebook_pages.find_all_by_page_id(page_ids)
          @edit_tab = true unless page_tabs.blank?
          page_tabs.each do |page_tab|
            page_tab.update_attribute(:page_token_tab, page_tab.page_id) if tabs_added[page_tab.page_id.to_s]
          end
        end
      }

      def profile_name(profile_id, fan_page)
        user = sandbox do
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

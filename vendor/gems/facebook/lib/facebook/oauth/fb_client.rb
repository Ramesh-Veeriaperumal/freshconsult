#This class is responsible for communication with facebook
# * builds the authorization url
# * create's facebook page objects (Social::FacebookPage)
# * updates facebook page token if any page tab is added
module Facebook
  module Oauth
    class FbClient
      
      include Facebook::Oauth::Constants
      include Facebook::Exception::Handler

      attr_accessor :fb_app_id, :call_back_url, :oauth

      # call_back_url is the url where facebook would redirect back with code after it authorizes
      def initialize(call_back_url, page_tab = false)
        @call_back_url = call_back_url
        if page_tab
          @fb_app_id     = FacebookConfig::PAGE_TAB_APP_ID
          secret_key     = FacebookConfig::PAGE_TAB_SECRET_KEY
        else
          @fb_app_id     = FacebookConfig::APP_ID
          secret_key     = FacebookConfig::SECRET_KEY
        end
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

        "#{url}?client_id=#{self.fb_app_id}&redirect_uri=#{self.call_back_url}&state=#{state}&scope=#{permissions}"
      end
      
      # Gets the access token and page token once code is passed
      def auth(code)
        oauth_access_token = @oauth.get_access_token(code)
        graph              = Koala::Facebook::API.new(oauth_access_token)
        pages              = graph.get_connections("me", "accounts")
        pages              = pages.collect{|p| p  unless p["category"].eql?("Application")}.compact
        REALTIME_BLOCK.call(pages, oauth_access_token)
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
            if page_source
              source_account = page_source.shard.domains.main_portal.first
              if source_account
                source_string = "#{source_account.domain}"
                page_id = nil
              end
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
            :enable_page     => true
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
          rest.get_object(profile_id).symbolize_keys
        end
        user ? "#{user[:first_name]} #{user[:last_name]}" : ""
      end

    end
  end
end

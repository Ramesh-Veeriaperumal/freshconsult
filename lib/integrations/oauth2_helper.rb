module Integrations::Oauth2Helper

	def get_oauth2_access_token(refresh_token)
		client = OAuth2::Client.new '3MVG9rFJvQRVOvk736MwC8D50iroLs6.IXQz_2Dsw4horjvxgK3tQcd7q7Pa2bcoemvR4_afG4u7PeUU8ZuFn', '3480279088976514323',
	             { :site          => 'https://login.salesforce.com',
	               :authorize_url => '/services/oauth2/authorize',
	               :token_url     => '/services/oauth2/token'
	              }
	      puts "client "
	      puts client.inspect
	      token_hash = { :refresh_token => refresh_token, :client_options => {
	        :site          => 'https://login.salesforce.com',
	        :authorize_url => '/services/oauth2/authorize',
	        :token_url     => '/services/oauth2/token'
	      },
	     :header_format => 'OAuth %s'}
	      access_token = OAuth2::AccessToken.from_hash(client, token_hash)
	      access_token.refresh!	
    end
end
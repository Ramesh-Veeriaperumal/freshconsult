class Collaboration::Ticket
	HK_CLIENT_ID = "hk"
	TOKEN_EXPIRY_TIME = 21600 # (in sec) 6 HRS
	DEF_PAGE_NUM = 1
	DEF_FETCH_LIMIT = 30
	FILTER_LIST = ["ongoing_collab"]
	ONGOING_COLLAB_ROUTE = "helpkit/users.ongoingcollab.get" # Todo (Mayank): move this to collab.yml

	class << self
		def fetch_tickets(count = DEF_FETCH_LIMIT, page_no = DEF_PAGE_NUM)
			#returns an array of objects of class Collaboration::Ticket
			@tickets = fetch_remote(count, page_no)
		end

		def fetch_count(count = DEF_FETCH_LIMIT, page_no = DEF_PAGE_NUM)
			#a seperate api to return just the count for pagination
			@tickets ||= []
			@tickets.length
		end

	    def convo_token(ticket_id)
	    	JWT.encode({
	    		:ConvoId => ticket_id.to_s, 
	    		:UserId => User.current.id.to_s, 
	    		:exp => (Time.now.to_i + TOKEN_EXPIRY_TIME)
	    	}, CollabConfig['secret_key'])
	    end

		def collab_token
			generate_collab_token
	    end

		private
		def fetch_remote(count = DEF_FETCH_LIMIT, page_no = DEF_PAGE_NUM)
			#does the remote call to fetch data
			uri = CollabConfig["collab_url"] + "/" + ONGOING_COLLAB_ROUTE + "?" + collab_tickets_param(count, page_no).to_query
			begin
				# TODO (mayank): Check for ssl issues 
				res = RestClient::Request.execute(
					:method => :get, 
					:url => uri, 
					:headers => { 
						'Authorization' =>  generate_collab_token(true),
						'ClientId' => HK_CLIENT_ID
				})
				Rails.logger.info "collab: res: #{res}."
			rescue  => e
				Rails.logger.error "collab: error: #{e}."
			end
			res.is_a?(String) && res.length > 0 ? parse(res) :  []
		end

		def collab_tickets_param(count = DEF_FETCH_LIMIT, page_no = DEF_PAGE_NUM)
			{
				:onlylist => true,
				:uid => User.current.id.to_s,
				:clientaccid => Account.current.id.to_s,
				:page_no => page_no,
				:limit => count,
				:fetch_total_count => true
			}
		end

		def parse(res)
			#parse data to create objects of Collaboration::Ticket
			JSON.parse(res.body)["conversations"].reject { |c| c.empty? }
		end

		def generate_collab_token(is_server=false)
			JWT.encode({
				:ClientId => HK_CLIENT_ID, 
				:ClientAccountId => Account.current.id.to_s, 
				:IsServer => (is_server ? "1" : "0"), 
				:UserId => User.current.id.to_s, 
				:exp => (Time.now.to_i + TOKEN_EXPIRY_TIME)
			}, CollabConfig['secret_key'])
		end
	end
end

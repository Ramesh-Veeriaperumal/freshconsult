class Collaboration::Ticket
	class << self
		def fetch_tickets(count = default_limit, page_no = default_page_number)
			Rails.logger.info "*** New structure calling"
			#returns an array of objects of class Collaboration::Ticket
			@tickets = fetch_remote(count, page_no)
		end

		def fetch_count(count = default_limit, page_no = default_page_number)
			#a seperate api to return just the count for pagination
			@tickets.length || 0
		end

	    def convo_token(ticket_id)
	    	JWT.encode({
	    		:ConvoId => ticket_id.to_s, 
	    		:UserId => User.current.id.to_s, 
	    		:exp => token_expiry_time
	    	}, CollabConfig['secret_key'])
	    end

		def filter_list
			[filters[:ongoing]]
		end

		def helpdesk_ticket
		 	#each collab ticket can reference a Helpdesk::Ticket
		end

		def collab_token
			generate_collab_token
	    end

		def client_id_helpkit
			generate_client_id
		end

		private
		def fetch_remote(count = default_limit, page_no = default_page_number)
			#does the remote call to fetch data
			Rails.logger.info "collab: Remote fetch count:#{count}, page_no:#{page_no}."
			default_res = Hash.new()
			res = default_res
			uri = CollabConfig["collab_url"] + "/" + ongoing_collab_route + "?" + collab_tickets_param(count, page_no).to_query
			Rails.logger.info "collab: Remote fetch Uri: #{uri}."
			begin
				# TODO (mayank): Check for ssl issues 
				res = RestClient::Request.execute(
					:method => :get, 
					:url => uri, 
					:headers => { 
						'Authorization' =>  generate_collab_token(true),
						'ClientId' => generate_client_id
				}) || default_res
				Rails.logger.info "collab: res: #{res}."
			rescue  StandardError => e
				Rails.logger.info "collab: error: #{e}."
			end
			res.is_a?(String) && res.length > 0 ? parse(res) :  []
		end

		def collab_tickets_param(count = default_limit, page_no = default_page_number)
			{
				:onlylist => true,
				:uid => User.current.id.to_s,
				:clientaccid => Account.current.id.to_s,
				:page_no => page_no,
				:limit => count,
				:fetch_total_count => true
			}
		end

		def filters
			{ :ongoing => "ongoing_collab" }
		end

		def ongoing_collab_route
			"helpkit/users.ongoingcollab.get"
		end

		def default_page_number
			1
		end

		def default_limit
			30
		end

		def parse(res)
			#parse data to create objects of Collaboration::Ticket
			JSON.parse(res.body)["conversations"].reject { |c| c.empty? }
		end

		def token_expiry_time
			# 6 HRS
			Time.now.to_i + 6 * 3600
		end

		def generate_client_id
			"hk"
		end

		def generate_collab_token(is_server=false)
			JWT.encode({
				:ClientId => generate_client_id, 
				:ClientAccountId => Account.current.id.to_s, 
				:IsServer => (is_server ? "1" : "0"), 
				:UserId => User.current.id.to_s, 
				:exp => token_expiry_time
			}, CollabConfig['secret_key'])
		end
	end
end

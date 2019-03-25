class Collaboration::Ticket
	include Collaboration::TicketFilter

	HK_CLIENT_ID = "hk"
  TOKEN_EXPIRY_TIME = 1_296_000 # (in sec) 15 DAYS
	DEF_PAGE_NUM = 1
	DEF_FETCH_LIMIT = 30
	FILTER_LIST = ["ongoing_collab"]
	ONGOING_COLLAB_ROUTE = "helpkit/users.ongoingcollab.get" # Todo (Mayank): move this to collab.yml
	GET_COLLAB_COUNT_ROUTE = "helpkit/users.ongoingcollab.getcount" # Todo (Mayank): move this to collab.yml
	SUB_FEATURES = ["group_collab"]
    COLLAB_TIMEOUT = 2

	def initialize(ticket_id=nil)
		@ticket = Account.current.tickets.find_by_display_id(ticket_id) if ticket_id
	end
  
	def access_token(for_user = nil, group_id = nil)
		token_data = {
			:ticketId => @ticket.display_id.to_s, 
			:userId => for_user || User.current.id.to_s, 
			:accountId => Account.current.id.to_s
		}
		token_data.merge!({:groupId => group_id}) if group_id.present?
		JWT.encode(token_data, Account.current.collab_settings.key)
	end

	def valid_token?(jwt_token)
		if jwt_token.present?
			parse_payload(jwt_token)
      decode_claim(jwt_token)
      valid_claims? && valid_group_claim?
    else
			false
		end
	end

    def fetch_collab_tickets
      return_value = []
      begin
        Timeout.timeout(COLLAB_TIMEOUT) do
          return_value = fetch_tickets
        end	
      rescue Timeout::Error => exception
        Rails.logger.info("Collab Timeout Exception - #{exception.message}")
      end
      return_value
    end

	def fetch_tickets
		# not using sent params for now will update later.
		# returns an array of objects of class Collaboration::Ticket
		@tickets ||= fetch_remote_tickets
	end

	def fetch_count
		@total_tickets ||= fetch_remote_count
	end

	def group_collab_with_filter_in_list_view?(filter_name)
		collab_filter_with_group_collab_for?(filter_name)
	end

	def convo_token(ticket_id)
	   	JWT.encode(convo_payload(ticket_id), CollabConfig['secret_key']) if User.current
	end

	def convo_payload(ticket_id)
		current_user = User.current
	    payload = {
	        ConvoId: ticket_id.to_s,
	        UserId: current_user.id.to_s,
	        exp: (Time.now.to_i + TOKEN_EXPIRY_TIME)
	    }
	    if freshid_authorization
		    uuid = { UserUUID: current_user.freshid_authorization.uid }
		    payload.merge!(uuid)
		end
		payload
	end

	def acc_auth_token
		generate_acc_auth_token
  end

  def ticket_payload
  	{
			:display_id => @ticket.display_id.to_s,
			:is_closed => @ticket.status == 5 || @ticket.status == 4 || @ticket.spam == true || @ticket.deleted == true,
			:responder_id => @ticket.responder_id.to_s,
			:convo_token => Collaboration::Ticket.new.convo_token(@ticket.display_id),
			:subject => @ticket.subject.html_safe,
			:account_suspended => Account.current.subscription.suspended?
		}.to_json if @ticket.present?
  end

  def account_payload
  	{
  		:client_id => HK_CLIENT_ID,
  		:client_account_id => Account.current.id.to_s,
			:init_auth_token => acc_auth_token,
			:collab_url => CollabConfig['collab_url'],
			:rts_url => CollabConfig['rts_url'],
			:user => {
				:uid => User.current.id.to_s,
				:name => User.current.name.html_safe,
				:email => User.current.email.html_safe,
			}
		}.to_json
  end

	private
	def parse_payload(jwt_token)
    header_segment, payload_segment, claim_segment = jwt_token.split('.')
    begin
      @payload = JSON.parse(JWT.base64url_decode(payload_segment), :symbolize_names => true) 
    rescue JSON::ParserError 
      raise JWT::DecodeError, 'Invalid segment encoding' 
    end
  end

	def decode_claim(jwt_token)
		secret = Account.current.collab_settings.key
		begin
	    @decoded_claim = JWT.decode(jwt_token, secret)[0].symbolize_keys
    rescue => jwt_error
      Rails.logger.info "Unable to decode jwt_token: #{jwt_token} secret: #{secret}. will ignore: #{jwt_error}"
    end
	end

	def valid_claims?
		@decoded_claim && 
			@decoded_claim[:accountId] == Account.current.id.to_s && 
			@decoded_claim[:ticketId] == @ticket.display_id.to_s && 
			@decoded_claim[:userId] == User.current.id.to_s
	end

	def valid_group_claim?
		# Group must be unavailable
		# if not, user must be member of group
		@decoded_claim[:groupId].blank? || User.current.group_member?(@decoded_claim[:groupId].to_i)
	end

	def fetch_remote_tickets
		res = get_remote("#{CollabConfig["collab_url"]}/#{ONGOING_COLLAB_ROUTE}?#{collab_tickets_param(DEF_FETCH_LIMIT, DEF_PAGE_NUM).to_query}")
		valid_res = res.is_a?(String) && res.length > 0
		valid_res ? JSON.parse(res.body)["conversations"].reject { |c| c.empty? } :  []
	end

	def fetch_remote_count
		res = get_remote("#{CollabConfig["collab_url"]}/#{GET_COLLAB_COUNT_ROUTE}?uid=#{User.current.id}")
		valid_res = res.is_a?(String) && res.length > 0
		valid_res ? JSON.parse(res)["collab_count"] :  0
	end

	def get_remote(uri)
		begin
			# TODO (mayank): Check for ssl issues 
			res = RestClient::Request.execute(
				:method => :get, 
				:url => uri, 
				:headers => { 
					'Authorization' =>  generate_acc_auth_token(true),
					'ClientId' => HK_CLIENT_ID
			})
			Rails.logger.info "collab: res: #{res}."
		rescue  => e
			Rails.logger.error "collab: error: #{e}."
		end
		res
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

	def generate_acc_auth_token(is_server=false)
		JWT.encode({
			:ClientId => HK_CLIENT_ID, 
			:ClientAccountId => Account.current.id.to_s, 
			:IsServer => (is_server ? "1" : "0"), 
			:UserId => User.current.id.to_s, 
			:exp => (Time.now.to_i + TOKEN_EXPIRY_TIME)
		}, Account.current.collab_settings.key)
	end

	def freshid_authorization
		Account.current.freshid_enabled? && User.current.freshid_authorization
	end
end

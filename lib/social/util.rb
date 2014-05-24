module Social::Util

  include Gnip::Constants
  include Social::Constants

  def select_shard_and_account(account_id)
    begin
      Sharding.select_shard_of(account_id) do
        account = Account.find_by_id(account_id)
        account.make_current if account
      end
      account = Account.current
      yield(account)
    rescue ActiveRecord::RecordNotFound => e
      #puts "Could not find account with id #{account_id}"
      custom_params = {
        :account_id => account_id,
        :description => "Could not find valid account id in DbUtil"
      }
      NewRelic::Agent.notice_error(e, :custom_params => custom_params)
    end
  end

  def helpdesk_ticket_link(item)
    return nil if item.nil? or item.id.nil? #if the ticket/note save failed or we requeue the feed
    if item.is_a?(Helpdesk::Ticket)
      link = "#{item.display_id}"
    elsif item.is_a?(Helpdesk::Note)
      ticket = item.notable
      link = "#{ticket.display_id}#note#{item.id}"
    end
  end

  def notify_social_dev(subject, message)
    message = {} unless message
    message.merge!(:environment => Rails.env)
    topic = SNS["social_notification_topic"]
    DevNotification.publish(topic, subject, message.to_json) unless Rails.env.test?
  end

  def select_valid_date(time, table="feeds")
    retention = TABLES[table][:retention_period]
    reference_date = Time.parse(TABLES[table][:db_reference_date])

    days = ((time - reference_date)/retention).to_i #Number of days since reference date
    date = reference_date + retention*days #Valid Date
    date.strftime("%Y%m%d")
  end

  def fd_info(notable, user)
    link = notable.nil? ? nil : helpdesk_ticket_link(notable)
    user = user.nil? ? nil : user.id
    {
      :fd_link => link,
      :fd_user => user
    }
  end

  def fetch_klout_score(screen_name)
    api_key = KloutConfig::API_KEY
    fetch_twitter_klout_score(api_key, screen_name)
  end


  private

  def fetch_twitter_klout_score(api_key, screen_name)
    klout_id_url =  URI.parse('http://api.klout.com/v2/identity.json/twitter?screenName='+screen_name+'&key='+api_key+'')
    klout_id_response = get_response(screen_name, api_key, klout_id_url)
    return 0 if klout_id_response == 0
    klout_id  = klout_id_response['id']
    score_url = URI.parse('http://api.klout.com/v2/user.json/'+klout_id.to_s+'?key='+api_key+'')
    score_response = get_response(screen_name, api_key, score_url)
    return 0 if score_response == 0
    klout_score = score_response['score']['score'].to_i
  end

  def get_response(screen_name, api_key, url)
    req      = Net::HTTP::Get.new(url.request_uri)
    http     = Net::HTTP.new(url.host, url.port)
    res      = http.start{|http| http.request(req) }
    body     = JSON.parse(res.body)
    response = body['error'] ? 0 : body # @REV raise dev notification in case of error?
  end

end

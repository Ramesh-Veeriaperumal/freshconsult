# NER API - Name Entity Recognizer (https://duckling.wit.ai/ for more info).
# API Params - text (data), user_id & client_id (customer & client), username (for authorization).

# User_id will be passed based on user_email. If it's not passed as an argument,
# we try to fetch email from the object that is passed, provided there is an association with the name 'user'

# This worker takes following params : obj_typ (Corresponding association name from Account/associations eg: notes, articles etc.,),
# obj_id, user_email (for user_id), text (data), html(optional param => To improve performance we send text data to api and will convert to html indexes from text indexes)

# As worker has customer & client information, encrypting both before passing it to API.
# API returns datetime information which is then passed on to a hook method store_ner_data.
# This has to be defined in the corresponding object's model

class NERWorker < BaseWorker

  sidekiq_options :queue => :ner_worker, :retry => 0, :failures => :exhausted
  MAXIMUM_LENGTH = 3000
  UTC_TIMEZONE = "Etc/UTC"

  def perform(args)
    args.symbolize_keys!
    account = Account.current

    obj = account.safe_send(args[:obj_type]).find(args[:obj_id])

    timezone = fetch_tzinfo(obj)

    text =  exclude_quoted_text?(obj) ? exclude_quoted_text(args[:html]) : args[:text]

    req_body = {  text: text.to_s.first(MAXIMUM_LENGTH), #Sending only first 3000 characters to api because the api response time is more than 4sec for the string length >3000
                  timezone: timezone }.to_json

    response = RestClient.safe_send("post", NER_API_TOKENS['datetime'], req_body, {"Content-Type"=>"application/json"})

    ner_data = JSON.parse(response)

    # If note body has time information, then set the memcache with NER API response
    # Memcache key will be empty If note body does not has the time information

    unless ner_data['datetimes'].empty?
      ner_data = NER::HtmlIndexTransformer.new( :ner_data => ner_data, 
        :text => text, :html => args[:html]).perform if args[:html]
      obj.store_ner_data(ner_data)
    end
  end

  private

  def fetch_pii(obj)
    obj.user.email ||  obj.user.phone|| obj.user.mobile || obj.user.twitter_id || Helpdesk::EMAIL[:default_requester_email]
    rescue
      Helpdesk::EMAIL[:default_requester_email]
  end

  # If it's a note & body & full_text length are same, it is possible that body will have quoted_text in it. 
  def exclude_quoted_text?(obj)
    (obj.class.name == "Helpdesk::Note") && (obj.body_html.length == obj.full_text_html.length)
  end

  def exclude_quoted_text(html_text)
    body_text = Nokogiri::HTML(html_text)
    body_text.search('.freshdesk_quote').remove
    text = Helpdesk::HTMLSanitizer.plain(body_text.to_html)
  end

  def fetch_tzinfo(obj)
    user_timezone = get_timezonemap(obj.user.time_zone)
    user_timezone ? user_timezone.tzinfo.name : get_timezonemap(obj.account.time_zone).tzinfo.name
    rescue
      UTC_TIMEZONE 
  end

  def get_timezonemap(tz)
    ActiveSupport::TimeZone.zones_map[tz]
  end
end

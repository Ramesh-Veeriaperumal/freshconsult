
# NER API - Name Entity Recognizer (https://duckling.wit.ai/ for more info).
# API Params - text (data), user_id & client_id (customer & client), username (for authorization).

# User_id will be passed based on user_email. If it's not passed as an argument,
# we try to fetch email from the object that is passed, provided there is an association with the name 'user'

# This worker takes following params : obj_typ (Corresponding association name from Account/associations eg: notes, articles etc.,),
# obj_id, user_email (for user_id), text (data) & html(optional param => To improve performance we send text data to api and will convert to html indexes from text indexes)

# As worker has customer & client information, encrypting both before passing it to API.
# API returns datetime information which is then passed on to a hook method store_ner_data.
# This has to be defined in the corresponding object's model

class NERWorker < BaseWorker

  sidekiq_options :queue => :ner_worker, :retry => 0, :backtrace => true, :failures => :exhausted
  MAXIMUM_LENGTH = 3000

  def perform(args)
    args.symbolize_keys!
    account = Account.current

    obj = account.send(args[:obj_type]).find(args[:obj_id])

    user_email = args[:user_email] || fetch_pii(obj)

    req_body = {  text: args[:text].to_s.first(MAXIMUM_LENGTH), #Sending only first 3000 characters to api because the api response time is more than 4sec for the string length >3000
                  user_id: encrypt_pii(user_email),
                  client_id: encrypt_pii(obj.account.full_domain),
                  username: NER_API_TOKENS['username'] }.to_json

    response = RestClient.send("post", NER_API_TOKENS['datetime'], req_body, {"Content-Type"=>"application/json"})

    ner_data = JSON.parse(response)

    # If note body has time information, then set the memcache with NER API response
    # Memcache key will be empty If note body does not has the time information

    unless ner_data['datetimes'].empty?
      ner_data = NER::HtmlIndexTransformer.new( :ner_data => ner_data, 
        :text => args[:text], :html => args[:html]).perform if args[:html]
      obj.store_ner_data(ner_data)
    end
  end

  private

  def fetch_pii(obj)
    obj.user.email ||  obj.user.phone|| obj.user.mobile || obj.user.twitter_id || Helpdesk::EMAIL[:default_requester_email]
    rescue
      Helpdesk::EMAIL[:default_requester_email]
  end

  def encrypt_pii(key)
    Encryptor.encrypt(value: key, key: NER_API_TOKENS['secret_key'], iv: NER_API_TOKENS['iv'])
  end
end

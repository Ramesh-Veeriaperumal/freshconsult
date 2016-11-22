module Tickets
  class UpdateSentimentWorker

    include Sidekiq::Worker
    include Redis::RedisKeys
    include Redis::OthersRedis

    sidekiq_options :queue => :update_sentiment,
                    :retry => 0,
                    :backtrace => true,
                    :failures => :exhausted

    def perform(args)
      args.symbolize_keys!
      begin
        @account = Account.current
        @ticket = @account.tickets.find_by_id args[:id]

        con = Faraday.new(MlAppConfig["sentiment_host"]) do |faraday|
            faraday.response :json, :content_type => /\bjson$/                # log requests to STDOUT
            faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end

        response = con.post do |req|
          req.url "/"+MlAppConfig["predict_url"]
          req.headers['Content-Type'] = 'application/json'
          req.body = generate_predict_request_body
        end

        Rails.logger.info "Response from ML : #{response.body["result"]}"

        @ticket.sentiment = response.body["result"]["sentiment"]
        @ticket.save

      rescue => e
        puts e.inspect, args.inspect
        raise
      end
    end

    def generate_predict_request_body
      body =  { :data => {

                  :account_id =>@account.id.to_s,
                  :ticket_id => @ticket.id.to_s,
                  :note_id => 0,
                  :text => @ticket.description,
                  :source => @ticket.source.to_s
                }
      }
      
     Rails.logger.info "Resquest to ML : #{body}"
     body.to_json
    end


  end
end

module Notes
  class UpdateNotesSentimentWorker

    include Sidekiq::Worker
    include Redis::RedisKeys
    include Redis::OthersRedis

    sidekiq_options :queue => :update_notes_sentiment,
                    :retry => 0,
                    :backtrace => true,
                    :failures => :exhausted

    def perform(args)
      args.symbolize_keys!
      begin
        puts "Came to notes worker..."

        @account = Account.current 
        @ticket = @account.tickets.find_by_id args[:ticket_id]
        @note = @account.notes.find_by_id args[:note_id]
        @note_body = :note_body

        puts "Account: #{@account}"
        puts "Ticket: #{@ticket}"
        puts "Note: #{@note}"
        puts "Note Body: #{@note.body}"

        con = Faraday.new(SentimentAppConfig["host"]) do |faraday|
            faraday.response :json, :content_type => /\bjson$/                # log requests to STDOUT
            faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end

        response = con.post do |req|
          req.url "/"+SentimentAppConfig["url"]
          req.headers['Content-Type'] = 'application/json'
          req.body = generate_predict_request_body
        end

        puts "Response from ML : #{response.body["result"]}"

        @note.sentiment = response.body["result"]["sentiment"]
        @note.save

      rescue => e
        puts e.inspect, args.inspect
        raise
      end
    end

    def generate_predict_request_body
      body =  { :data => {

                  :account_id =>@account.id.to_s,
                  :ticket_id => @ticket.id.to_s,
                  :note_id => @note_id,
                  :text => @note.body,
                  :source => @ticket.source.to_s
                }
      }
      
     Rails.logger.info "Resquest to ML : #{body}"
     body.to_json
    end


  end
end

class Bot::MlSolutionsTraining < BaseWorker

  sidekiq_options queue: :ml_solutions_training, retry: 3,  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    @bot = Account.current.bots.where(id: args[:bot_id]).first
    @portal = Account.current.portals.where(id: @bot.portal_id).first
    push_payload(@bot, :ml_training_start)
    begin
      portal_categories.each do |category_meta|
        next if category_meta.is_default?
        push_payload(category_meta.primary_category, :ml_training_category)
        category_meta.solution_folder_meta.each do |folder_meta|
          push_payload(folder_meta.primary_folder, :ml_training_folder)
          folder_meta.solution_article_meta.each do |article_meta|
            primary_article = article_meta.primary_article
            next unless primary_article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
            push_payload(primary_article, :ml_training_article)
          end
        end
      end
      @bot.training_completed = true
    rescue => e
      @bot.training_completed = false
      raise e
    ensure
      push_payload(@bot, :ml_training_end)
    end
  rescue => e
    NewRelic::Agent.notice_error(e)
    Rails.logger.error("ML Solutions Training Failure :: Account id : #{Account.current.id} :: Portal id : #{@portal.id} :: Bot id : #{@bot.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}")
  end

  private

    def push_payload(object, payload_type)
      conn = CentralPublisher.configuration.central_connection
      response = conn.post { |r| r.body = request_body(object, payload_type) }
      if response.status == 202
        Rails.logger.info("ML Solutions Training Central Publish Success :: Account id : #{Account.current.id} :: Portal id : #{@portal.id} :: Bot id : #{@bot.id} #{response.body}")
      else
        raise "Central publish failed with response code : #{response.status} :: Response : #{response.inspect}"
      end
    end

    def portal_categories
      @portal.solution_category_meta.includes([:primary_category, { portals: :portal_solution_categories }, { solution_folder_meta: [ :primary_folder, { solution_article_meta: [ { primary_article: [ :article_body, :attachments, :tags ] }, :solution_category_meta ] } ]}])
    end

    def request_body(object, payload_type)
      {
        account_id: Account.current.id.to_s,
        payload_type: payload_type,
        payload: training_payload(object, payload_type)
      }.to_json
    end

    def training_payload(object, payload_type)
      object.central_payload_type = payload_type
      {
        account_full_domain: Account.current.full_domain,
        model_properties: object.central_publish_payload
      }
    end
end

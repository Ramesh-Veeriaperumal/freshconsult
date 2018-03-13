class Bot::FeedbackProcessor

  EXPECTED_FIELDS = [:queryId, :extClientId, :queryDate, :ticketId, :query, :type, :customerId, :clientId]

  def initialize(args)
    @account_id       = args[:account_id]
    @payload          = args[:payload]
  end

  def process
    Sharding.select_shard_of(@account_id) do
      save_bot_feedback if valid_account? && valid_bot?
    end
  rescue => e
    Rails.logger.error "FeedbackProcessorError : Account : --- #{@account_id} --- Payload : --- #{@payload} --- Error: --- #{e.inspect}"
  end

  def valid?
    return false unless @account_id.present? && @payload.present?
    EXPECTED_FIELDS.all? { |pay| @payload[pay].present? }
  end

  private

    def valid_account?
      return false unless (@account = Account.find_by_id(@account_id))
      @account.make_current
      return false unless @account.support_bot_enabled?
      return true
    end

    def valid_bot?
      (@bot = @account.bots.find_by_external_id(@payload[:extClientId])).present?
    end

    def save_bot_feedback
      @feedback = @bot.bot_feedbacks.find_by_query_id(@payload[:queryId])
      @feedback ? update_feedback : create_feedback
    end

    def create_feedback
      bot_feedback = @bot.bot_feedbacks.build(bot_feedback_params)
      bot_feedback.save!
    end

    def update_feedback
      @feedback.attributes = bot_feedback_params.slice(:useful, :category, :received_at, :suggested_articles)
      @feedback.save!
    end

    def bot_feedback_params
      populate_category_useful
      {
        bot_id:               @bot.id,
        account_id:           @account_id,
        category:             @category,
        useful:               @useful,
        received_at:          @payload[:queryDate],
        query_id:             @payload[:queryId],
        query:                @payload[:query],
        external_info:        { chat_id: @payload[:ticketId], customer_id: @payload[:customerId], client_id: @payload[:clientId]},
        state:                BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:default],
        suggested_articles:   suggested_articles
      }
    end

    def suggested_articles
      @payload[:faqs].select{|a| a.deep_symbolize_keys}
    end

    def populate_category_useful
      if @payload[:type] == "TRAINING"
        @category = BotFeedbackConstants::FEEDBACK_CATEGORY_KEYS_BY_TOKEN[:unanswered]
        @useful   = BotFeedbackConstants::FEEDBACK_USEFUL_KEYS_BY_TOKEN[:default]
      else
        if @payload.has_key?(:useful)
          @category = @payload[:useful] ? BotFeedbackConstants::FEEDBACK_CATEGORY_KEYS_BY_TOKEN[:answered] : BotFeedbackConstants::FEEDBACK_CATEGORY_KEYS_BY_TOKEN[:unanswered]
          @useful   = @payload[:useful] ? BotFeedbackConstants::FEEDBACK_USEFUL_KEYS_BY_TOKEN[:yes] : BotFeedbackConstants::FEEDBACK_USEFUL_KEYS_BY_TOKEN[:no]
        else
          @category =  BotFeedbackConstants::FEEDBACK_CATEGORY_KEYS_BY_TOKEN[:answered]
          @useful   =  BotFeedbackConstants::FEEDBACK_USEFUL_KEYS_BY_TOKEN[:default]
        end
      end
    end

end
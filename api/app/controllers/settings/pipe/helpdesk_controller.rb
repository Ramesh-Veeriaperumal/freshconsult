module Settings::Pipe
  class HelpdeskController < ::Settings::HelpdeskController
    include Redis::RedisKeys
    include Redis::DisplayIdRedis
    include Redis::RateLimitRedis

    before_filter :validate_api_limit_params, only: :change_api_v2_limit
    before_filter :validate_params, only: [:toggle_email, :toggle_fast_ticket_creation]

    def toggle_email
      if params[:disabled] == true
        Account.current.enable_setting(:disable_emails)
      else
        Account.current.disable_setting(:disable_emails)
      end
      @item = { disabled: Account.current.disable_emails_enabled? }
    end

    def change_api_v2_limit
      max_limit = Pipe::HelpdeskConstants::MAX_API_LIMIT
      old_limit = get_account_api_limit
      old_limit = old_limit.to_i if old_limit
      limit = (params[:limit] && params[:limit] > max_limit) ? max_limit : params[:limit]
      set_account_api_limit(limit)
      new_limit = get_account_api_limit
      new_limit = new_limit.to_i if new_limit
      @item = { old_limit: old_limit, limit: new_limit }
    end

    def toggle_fast_ticket_creation
      account = Account.current
      if params[:disabled] == true
        account.features.redis_display_id.destroy if account.features?(:redis_display_id)
      else
        key = TICKET_DISPLAY_ID % { account_id: Account.current.id }
        set_display_id_redis_key(key, TicketConstants::TICKET_START_DISPLAY_ID)
        account.features.redis_display_id.create unless account.features?(:redis_display_id)
      end
      Account.current.reload
      @item = { disabled: !Account.current.features?(:redis_display_id) }
    end

    private

      def validate_params
        field = 'disabled'
        params[cname].permit(*field)
        toggle = Pipe::HelpdeskValidation.new(params)
        render_custom_errors(toggle, true) unless toggle.valid?
      end

      def validate_api_limit_params
        field = 'limit'
        params[cname].permit(*field)
        toggle = Pipe::HelpdeskValidation.new(params)
        render_custom_errors(toggle, true) unless toggle.valid?
      end

      def account_api_limit_key
        ACCOUNT_API_LIMIT % { account_id: Account.current.id }
      end
  end
end

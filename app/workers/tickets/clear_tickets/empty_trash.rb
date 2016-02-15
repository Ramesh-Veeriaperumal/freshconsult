class Tickets::ClearTickets::EmptyTrash < Tickets::ClearTickets::BaseWorker
  include Redis::RedisKeys
  protected
    def key
      EMPTY_TRASH_TICKETS % {:account_id => Account.current.id} 
    end

    def batch_parameters(args)
      batch_params = {}
      if args[:clear_all]
        max_display_id = Account.current.get_max_display_id
        batch_params[:conditions] = ['deleted = true and display_id < ?', max_display_id]
      elsif args[:ticket_ids].present?
        batch_params[:conditions] = ["deleted = true and id in (#{args[:ticket_ids].join(',')})"]
      else
        batch_params = nil     
      end
      batch_params
    end
end

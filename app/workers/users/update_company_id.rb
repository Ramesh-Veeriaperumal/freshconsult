class Users::UpdateCompanyId < BaseWorker
  
  sidekiq_options :queue => :update_users_company_id, 
                  :retry => 0, 
                  :backtrace => true, 
                  :failures => :exhausted

  USER_FETCH_LIMIT = 500
  TICKET_UPDATE_LIMIT = 50

  def perform(args)
    args.symbolize_keys!
    domains = args[:domains]
    company_id = args[:company_id]
    current_company_id = args[:current_company_id]
    account = Account.current
    cust_id_cdn = company_id ? "customer_id is null" : "customer_id = #{current_company_id}"
    last_user_id = nil
    begin
      # Not using find_in_batches `cause of inability to update_all an array
      batch_op = last_user_id ? "AND id > #{last_user_id}" : ""
      condition = "#{cust_id_cdn} and helpdesk_agent = 0 #{batch_op}"
      users = account.all_users.where(["SUBSTRING_INDEX(email, '@', -1) IN (?) and  #{condition}", 
                                      get_domain(domains)]).limit(USER_FETCH_LIMIT)


      user_ids = execute_on_db { users.pluck(:id) }
      if user_ids.present?
        last_user_id = user_ids.last
        updated_users = users.update_all(:customer_id => company_id)
        user_ids.each_slice(TICKET_UPDATE_LIMIT) do |ids|
          Tickets::UpdateCompanyId.perform_async({ :user_ids => ids, :company_id => company_id })
        end
      end
    end while updated_users == USER_FETCH_LIMIT
  end

  def get_domain(domains)
    domains.map{ |s| s.gsub(/^(\s)?(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') }
  end
end

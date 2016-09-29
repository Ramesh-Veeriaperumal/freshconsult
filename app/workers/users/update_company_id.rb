class Users::UpdateCompanyId < BaseWorker
  
  sidekiq_options :queue => :update_users_company_id, 
                  :retry => 2, 
                  :backtrace => true, 
                  :failures => :exhausted

  USER_FETCH_LIMIT = 100
  TICKET_UPDATE_LIMIT = 50

  def perform(args)
    args.symbolize_keys!
    domains = args[:domains]
    company_id = args[:company_id]
    current_company_id = args[:current_company_id]
    account = Account.current
    
    select_columns = ["users.id", "users.privileges"]
    joins = "left join user_companies ON users.account_id = user_companies.account_id AND users.id = user_companies.user_id"
    cid = company_id ? "user_companies.id IS NULL" : "user_companies.company_id = #{current_company_id}"
    company_id_cdn = "#{cid} and helpdesk_agent = 0"
    conditions = domains.present? ? ["SUBSTRING_INDEX(email, '@', -1) IN (?) and #{company_id_cdn}", 
                                     domains] :
                                    company_id_cdn
    
    Sharding.run_on_slave do 
      account.all_users.joins(joins).where(conditions).select(select_columns).find_in_batches(:batch_size => USER_FETCH_LIMIT) do |users|
        user_ids = []
        contractor_ids = []
        users.map { |user| user.contractor? ? contractor_ids.push(user.id) : user_ids.push(user.id) }
        company_id ? create_user_companies(account, user_ids, company_id) : 
                     destroy_user_companies(account, user_ids, current_company_id) if user_ids.any?
        destroy_contractor_companies(account, contractor_ids, current_company_id) if (!company_id && 
          contractor_ids.present? && account.companies.find_by_id(current_company_id).nil?)
      end
    end
  end

  def create_user_companies(account, user_ids, company_id)
    Sharding.run_on_master do 
      user_ids.each do |user_id|
        account.user_companies.create(:company_id => company_id, :user_id => user_id, :default => true)
      end
      account.users.where("id in (?)", user_ids).update_all(:customer_id => company_id)
    end
  end

  def destroy_user_companies(account, user_ids, company_id)
    Sharding.run_on_master do 
      account.user_companies.where(["user_id in (?) and company_id = ?", user_ids, company_id]).destroy_all
      account.users.where("id in (?)", user_ids).update_all(:customer_id => nil)
    end
  end

  def destroy_contractor_companies(account, user_ids, company_id)
    Sharding.run_on_master do 
      account.user_companies.where(["user_id in (?) and company_id = ?", user_ids, company_id]).destroy_all
    end
  end
end

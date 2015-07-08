
class ShardMapping < ActiveRecord::Base
  
  self.primary_key = :account_id
  not_sharded


  STATUS_CODE = {:partial => 206, :ok => 200, :not_found => 404, :blocked => 403}

  has_many :domains,:class_name => 'DomainMapping',:dependent => :destroy,:foreign_key => :account_id
  has_many :facebook_pages, :class_name => 'FacebookPageMapping', :dependent => :destroy, :foreign_key => :account_id
  has_one :google_domain,:class_name => 'GoogleDomain', :dependent => :destroy, :foreign_key => :account_id

  after_update :clear_cache
  after_destroy :clear_cache

 def self.lookup_with_account_id(shard_key)
   shard =  fetch_by_account_id(shard_key) 
 end

 def self.lookup_with_domain(shard_key)
   shard = fetch_by_domain(shard_key)
 end

 def self.fetch_by_domain(domain)
   return if domain.blank?
   key = MemcacheKeys::SHARD_BY_DOMAIN % { :domain => domain }
   MemcacheKeys.fetch(key) { 
    domain_maping = DomainMapping.find_by_domain(domain)
    domain_maping.shard if domain_maping
  }
 end
    
 def self.fetch_by_account_id(account_id)
   return if account_id.blank?
   key = MemcacheKeys::SHARD_BY_ACCOUNT_ID % { :account_id => account_id }
   MemcacheKeys.fetch(key) { self.find_by_account_id(account_id) }
 end

 def self.latest_shard
  if Rails.env.development? or Rails.env.test? 
    "shard_1"
  else
    AppConfig['latest_shard']
  end
 end

 def ok?
  status == 200
 end

 def blocked?
  status == STATUS_CODE[:blocked]
 end

 def clear_cache
    domains.each {|d| d.clear_cache }
    key = MemcacheKeys::SHARD_BY_ACCOUNT_ID % { :account_id => account_id }
    MemcacheKeys.delete_from_cache key
  end


  private
    def update_pod_shard_condition
      # Rails.logger.info "on pod info changed."
      if pod_info_changed?
        Rails.logger.info "Pod info has changed. Updating the account condition.  Old pod_info is: #{self.pod_info_was}. New pod_info: #{self.pod_info}."
        check_and_update_condition(pod_info_was, pod_info, account_id.to_s)
      end
    end

    def check_and_update_condition(old_pod_info, new_pod_info, account_id)
      shard_name = self.shard_name

      # old
      old_row = PodShardCondition.find_by_pod_info_and_shard_name(old_pod_info, shard_name)
      if old_row
        old_row.accounts = update_accounts(old_row.accounts, account_id)
        old_row.save!
      else
        # create the row with query_type as 'not in' and account id
        pod_shard_condition = PodShardCondition.new({:pod_info => old_pod_info, :shard_name => shard_name, 
                                                      :query_type => 'not in', :accounts => account_id})
        pod_shard_condition.save!
      end

      # new
      new_row = PodShardCondition.find_by_pod_info_and_shard_name(new_pod_info, shard_name)
      if new_row
        new_row.accounts = update_accounts(new_row.accounts, account_id)
        new_row.save!
      else
        # create the row with query_type 'in' and account_id
        pod_shard_condition = PodShardCondition.new({:pod_info => new_pod_info, :shard_name => shard_name, 
                                                      :query_type => 'in', :accounts => account_id})
        pod_shard_condition.save!
      end
    end

    def update_accounts(accs, account_id)
      accounts = accs.split(',')
      index = accounts.index(account_id)

      if index
        # delete if account exists
        accounts.delete_at(index)
      else
        # else add account id
        accounts << account_id
      end
      accounts.join(',')
    end

    def clear_account_in_pod_shard_condtion
      # Remove the acccount ID from the pod shard condition. 
      # Here only current pod would be available. The old pod info would be still be present in the table.

      Rails.logger.info "Clearing account id #{self.account_id} from the PodShardCondition."
      condition_row = PodShardCondition.find_by_pod_info_and_shard_name(self.pod_info, self.shard_name)
      if condition_row
        accounts = condition_row.accounts.split(',')
        index = accounts.index(self.account_id.to_s)

        if index
          # delete if account exists
          accounts.delete_at(index)
        end
        condition_row.accounts = accounts.join(',')
        condition_row.save!
      end
    end

end
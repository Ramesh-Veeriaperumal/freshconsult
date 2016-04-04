module PodHelper
  module ClassMethods
   
    def pod_filter(_pod_filter_column = "account_id")
      @pod_filter_column = _pod_filter_column
    end

    protected
      def get_pod_filter
        @pod_filter_column
      end

    private
      def shard_account_condition
        if Thread.current[:shard_selection].shard
          return false
          if self.is_sharded?
            filter = get_pod_filter || "account_id"
            details = PodShardCondition.fetch_details
            if details
              condition_part = "#{table_name}.#{filter} #{details.query_type} (#{details.accounts}) " if details.query_type && !details.accounts.blank?
            end
            condition_part
          end
        else
          error_string = 'Unable to determine current shard.'
          Rails.logger.error(error_string)
          NewRelic::Agent.notice_error(error_string)
        end
      end
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.class_eval do
      scope :current_pod, lambda  {cond = shard_account_condition 
                                      {:conditions => ["#{cond}"]} if cond
                                    }
    end
  end
end

ActiveRecord::Base.send :include, PodHelper
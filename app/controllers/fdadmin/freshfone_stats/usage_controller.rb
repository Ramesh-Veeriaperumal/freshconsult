module Fdadmin
  module FreshfoneStats
    # Usage Stats
    class UsageController < Fdadmin::DevopsMainController
      include Fdadmin::FreshfoneStatsMethods

      around_filter :select_slave_shard, only: [:global_conference_usage_csv_by_account]
      before_filter :load_account, only: [:global_conference_usage_csv_by_account]
      before_filter :validate_freshfone_account, only: [:global_conference_usage_csv_by_account]

      def global_conference_usage_csv
        render json: Freshfone::Account.global_conference_usage(
          params[:startDate], params[:endDate])
      end

      def global_conference_usage_csv_by_account
        render json: @account.freshfone_account.global_conference_usage(
          params[:startDate], params[:endDate])
      end
    end
  end
end

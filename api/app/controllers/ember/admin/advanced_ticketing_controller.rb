module Ember
  module Admin
    class AdvancedTicketingController < ApiApplicationController
      before_filter :validate_destroy, only: :destroy
      before_filter :check_privilege_for_fsm_disable, only: :destroy, if: -> { fsm? }

      include HelperConcern
      include Integrations::AdvancedTicketing::AdvFeatureMethods
      include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
      include Redis::RedisKeys
      include Redis::HashMethods

      def create
        disable_old_ui_enabled? ? (add_feature cname_params[:name].to_sym) : @item.save!
        head 204
      rescue Exception => e
        Rails.logger.error("Exception while creating advanced ticketing app, account::#{current_account.id}, message::#{e.message}, backtrace::#{e.backtrace.join('\n')}")
        render_errors({message: e.message})
      end

      def destroy
        remove_feature params[:id].to_sym if disable_old_ui_enabled?
        @item.destroy if @item
        head 204
      rescue Exception => e
        Rails.logger.error("Exception while deleting advanced ticketing app, account::#{current_account.id}, message::#{e.message}, backtrace::#{e.backtrace.join('\n')}")
        render_errors({message: e.message})
      end

      def insights
        return unless validate_query_params
        @items = multi_get_all_redis_hash(ADVANCED_TICKETING_METRICS)
        @items = insights_from_s3 if @items.empty?
      end

      private

      def constants_class
        'AdvancedTicketingConstants'.freeze
      end

      def scoper
        current_account.installed_applications
      end

      def load_object
        log_and_render_404 unless (@item = scoper.with_name(params[:id]).first) || disable_old_ui_enabled?
      end

      def disable_old_ui_enabled?
        current_account.disable_old_ui_enabled?
      end

      def load_application_by_name(app_name)
        @application = Integrations::Application.available_apps(current_account.id).find_by_name(app_name)
      end

      def validate_params
        return unless validate_body_params
        load_application_by_name(cname_params[:name])
        return unless validate_delegator(@application, { feature: cname_params[:name] })
      end

      def build_object
        return if disable_old_ui_enabled?
        @item = Integrations::InstalledApplication.new({account: current_account, application: @application})
      end

      def insights_from_s3
        Rails.logger.info("Retrieving insights from s3-baikal, Account::#{current_account.id}")
        metrics_data = JSON.parse(AwsWrapper::S3Object.read(AdvancedTicketingConstants::S3_FILE_PATH, S3_CONFIG[:baikal_bucket]))
        multi_set_redis_hash(ADVANCED_TICKETING_METRICS, metrics_data.to_a.flatten, AdvancedTicketingConstants::REDIS_EXPIRY)
        metrics_data
      rescue Exception => e
        Rails.logger.error("Exception while getting insights, Account::#{current_account.id}, Exception::#{e.message}")
        NewRelic::Agent.notice_error(e, description: "Exception while fetching metrics from s3 for account::#{current_account.id}")
        render_base_error(:internal_error, 500)
      end

      def validate_destroy
        validate_query_params
        validate_delegator(nil, { feature: params[:id] })
      end

      def check_privilege_for_fsm_disable
        render_request_error :access_denied, 403 unless User.current.privilege?(:manage_account)
      end
    end
  end
end

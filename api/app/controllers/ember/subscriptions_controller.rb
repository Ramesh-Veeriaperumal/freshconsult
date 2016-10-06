module Ember
  class SubscriptionsController < ApiApplicationController
    include TicketConcern

    def watchers
      @items = @item.subscriptions.map(&:user_id)
    end

    def watch
      return unless validate_params
      sanitize_params
      @subscription = @item.subscriptions.build(user_id: params[cname][:user_id])
      subscription_delegator = SubscriptionDelegator.new(@subscription)
      if subscription_delegator.valid?
        create_watcher ? (head 204) : render_errors(@subscription.errors)
      else
        render_custom_errors(subscription_delegator, true)
      end
    end

    def unwatch
      subscription = @item.subscriptions.find_by_user_id(api_current_user.id)
      subscription ? subscription.destroy : (return head 404)
      head 204
    end

    def self.wrap_params
      SubscriptionConstants::WRAP_PARAMS
    end

    private

      def scoper
        current_account.tickets
      end

      def validate_params
        return true unless params[cname]
        params[cname].permit(*SubscriptionConstants::WATCH_FIELDS)
        @subscription_validation = SubscriptionValidation.new(params[cname], @item, string_request_params?)
        valid = @subscription_validation.valid?
        render_errors @subscription_validation.errors, @subscription_validation.error_options unless valid
        valid
      end

      def sanitize_params
        params[cname] ||= {}
        params[cname][:user_id] ||= api_current_user.id
      end

      def load_object(items = scoper)
        @item = items.find_by_display_id(params[:id])
        log_and_render_404 unless @item
      end

      def after_load_object
        if SubscriptionConstants::TICKET_PERMISSION_REQUIRED.include?(action_name.to_sym)
          return false unless verify_ticket_permission
        end

        if SubscriptionConstants::NO_PARAM_ROUTES.include?(action_name) && params[cname].present?
          render_request_error :no_content_required, 400
        end
      end

      def create_watcher
        return false unless @subscription.save
        if @subscription.user_id != api_current_user.id
          Helpdesk::WatcherNotifier.send_later(:deliver_notify_new_watcher,
                                               @item,
                                               @subscription,
                                               api_current_user.name)
        end
        true
      end

      # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
      wrap_parameters(*wrap_params)
  end
end

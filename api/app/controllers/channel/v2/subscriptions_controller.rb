# frozen_string_literal: true

class Channel::V2::SubscriptionsController < Admin::SubscriptionsController
  include ChannelAuthentication
  include Channel::V2::SubscriptionConstants
  decorate_views

  skip_before_filter :check_privilege, if: :skip_privilege_check?
  before_filter :channel_client_authentication
  before_filter :sanitize_params, only: :update

  PERMITTED_JWT_SOURCES = [:multiplexer].freeze

  def update
    super
  end

  def self.decorator_name
    Admin::SubscriptionDecorator
  end

  private

    def skip_privilege_check?
      permitted_jwt_source? PERMITTED_JWT_SOURCES
    end

    def fields_to_validate
      return super unless update?

      UPDATE_FIELDS
    end

    def validation_klass
      'Channel::V2::SubscriptionValidation'.constantize
    end

    def sanitize_params
      params[cname]['addons']['add'] = params[cname]['addons']['add'].uniq
      params[cname]['addons']['remove'] = params[cname]['addons']['remove'].uniq
    end
end

module Freshfone
  class Subscription < ActiveRecord::Base
    self.table_name  = :freshfone_subscriptions
    self.primary_key = :id

    belongs_to_account

    belongs_to :freshfone_account, class_name: 'Freshfone::Account'

    serialize :inbound
    serialize :outbound
    serialize :numbers
    serialize :calls_usage

    INBOUND = [
      [:call_duration,      110], # in seconds
      [:exceeded,         false], # bool
      [:minutes,             25],
      [:trigger, :calls_inbound]
    ]

    OUTBOUND = [
      [:call_duration,       110],
      [:exceeded,          false],
      [:minutes,               5],
      [:trigger, :calls_outbound]
    ]

    NUMBERS = [
      [:credit, 1.0],
      [:count,    1]
    ]

    INBOUND_HASH  = Hash[*INBOUND.map { |i| [i[0], i[1]] }.flatten]
    OUTBOUND_HASH = Hash[*OUTBOUND.map { |i| [i[0], i[1]] }.flatten]
    NUMBERS_HASH  = Hash[*NUMBERS.map { |i| [i[0], i[1]] }.flatten]

    TRIAL_PERIOD_THRESHOLD           =  3
    TRIAL_INCOMING_MINUTES_THRESHOLD =  5
    TRIAL_OUTGOING_MINUTES_THRESHOLD =  2
    TOTAL_TRIAL_PERIOD               = 15
    DEFAULT_CALLS_USAGE_HASH         = {
      cost: 0.0, minutes: { incoming: 0, outgoing: 0 }
    }

    NUMBERS_HASH.each_pair do |key, _value|
      define_method "number_#{key}" do
        numbers[key]
      end
    end

    def inbound_usage_exceeded!
      inbound[:exceeded] = true
      save!
    end

    def inbound_usage_exceeded?
      inbound[:exceeded]
    end

    def outbound_usage_exceeded!
      outbound[:exceeded] = true
      save!
    end

    def outbound_usage_exceeded?
      outbound[:exceeded]
    end

    def add_to_numbers_usage(rate)
      Rails.logger.info "Added to Freshfone Trial Numbers Usage For account 
        :: #{account_id} of Rate :: #{rate}"
      self.numbers_usage += rate
      save!
    end

    def add_to_others_usage(rate)
      Rails.logger.info "Added to Freshfone Trial Others Usage For account 
        :: #{account_id} of Rate :: #{rate}"
      self.others_usage += rate
      save!
    end

    def add_to_calls_usage(rate)
      Rails.logger.info "Added to Freshfone Trial Calls Usage For account
        :: #{account_id} of Rate :: #{rate}"
      self.calls_usage[:cost] += rate
      save!
    end

    def add_to_calls_minutes(call_type, seconds) # adding pulse
      self.calls_usage[:minutes][resolve_call_type(call_type)] +=
        (seconds / 1.minute.to_f).ceil
      save!
    end

    def trial_expired?
      Time.zone.now > expiry_on
    end

    def about_to_expire?
      (Time.zone.now + TRIAL_PERIOD_THRESHOLD.days) >= expiry_on
    end

    def trial_period_left # in days
      ((expiry_on - Time.zone.now) / 1.day).ceil
    end

    def incoming_warning?
      pending_incoming_minutes <= TRIAL_INCOMING_MINUTES_THRESHOLD
    end

    def outgoing_warning?
      pending_outgoing_minutes <= TRIAL_OUTGOING_MINUTES_THRESHOLD
    end

    def pending_incoming_minutes
      self.inbound[:minutes] - self.calls_usage[:minutes][:incoming]
    end

    def pending_outgoing_minutes
      self.outbound[:minutes] - self.calls_usage[:minutes][:outgoing]
    end

    def trial_warnings?
      inbound_usage_exceeded? || outbound_usage_exceeded? || about_to_expire? ||
        incoming_warning? || outgoing_warning?
    end

    def allowed_number_credit
      number_credit || NUMBERS_HASH[:credit]
    end

    def allowed_number_limit
      number_count || NUMBERS_HASH[:count]
    end

    def trial_limits_breached?
      self.inbound_usage_exceeded? && self.outbound_usage_exceeded?
    end

    def self.create_or_update_trial_subscription(account, options = {})
      subscription = Freshfone::Subscription
          .find_or_initialize_by_account_id(account.id) do |ff_subscription|
            ff_subscription.inbound       = INBOUND_HASH.except(:trigger)
            ff_subscription.outbound      = OUTBOUND_HASH.except(:trigger)
            ff_subscription.numbers       = NUMBERS_HASH
            ff_subscription.calls_usage   = DEFAULT_CALLS_USAGE_HASH
            ff_subscription.numbers_usage = options[:numbers_usage] || 0.0
            ff_subscription.expiry_on     = TOTAL_TRIAL_PERIOD.days.from_now
          end
      subscription.freshfone_account = account.freshfone_account
      subscription.numbers_usage += (options[:numbers_usage] || 0.0) unless
        subscription.new_record?
      subscription.save!
    end

    def self.fetch_number_credit(account)
      subscription = account.freshfone_subscription
      subscription.present? ?
        subscription.allowed_number_credit : NUMBERS_HASH[:credit]
    end

    def self.fetch_number_count(account, subscription = nil)
      subscription ||= account.freshfone_subscription
      return subscription.allowed_number_limit if subscription.present?
      NUMBERS_HASH[:count]
    end

    def self.number_purchase_allowed?(account)
      (account.freshfone_numbers.count <
        fetch_number_count(account))
    end

    def call_duration(call_type = Freshfone::Call::CALL_TYPE_HASH[:incoming])
      return incoming_limit if
        call_type == Freshfone::Call::CALL_TYPE_HASH[:incoming]
      outgoing_limit
    end

    def incoming_trial_warnings
      [incoming_usage_warning, trial_to_expire_warning].inject(&:merge)
    end

    def outgoing_trial_warnings
      [outgoing_usage_warning, trial_to_expire_warning].inject(&:merge)
    end

    private

      def incoming_limit
        return pending_incoming_minutes.minutes.seconds if
          pending_incoming_minutes.minutes.seconds <= inbound[:call_duration]
        inbound[:call_duration] || INBOUND_HASH[:call_duration]
      end

      def outgoing_limit
        return pending_outgoing_minutes.minutes.seconds if
          pending_outgoing_minutes.minutes.seconds <= outbound[:call_duration]
        outbound[:call_duration] || OUTBOUND_HASH[:call_duration]
      end

      def incoming_usage_warning
        return {} unless incoming_warning?
        { trial_inbound_left: pending_incoming_minutes }
      end

      def transfer_outgoing_warning(call)
        return {} unless call.outgoing? && call.parent.present? # for transfer
        outgoing_usage_warning
      end

      def trial_to_expire_warning
        return {} unless about_to_expire?
        { trial_period_left: trial_period_left }
      end

      def outgoing_usage_warning
        return {} unless outgoing_warning?
        { trial_outbound_left: pending_outgoing_minutes }
      end

      def resolve_call_type(type)
        return :incoming if type == Freshfone::Call::CALL_TYPE_HASH[:incoming]
        :outgoing
      end
  end
end

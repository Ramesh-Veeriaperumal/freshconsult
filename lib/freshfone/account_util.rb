module Freshfone::AccountUtil

  def create_freshfone_account(account = nil)
    account = current_account if defined?(current_account) && account.blank?
    Freshfone::SubAccount.new(account, params).create 
  end

  class Freshfone::SubAccount
    include Freshfone::SubscriptionsUtil

    attr_accessor :account, :params

    def initialize(account, params = {})
      self.account = account
      self.params = params
    end

    def create
      return unless valid_request
      return existing_freshfone_account if existing_freshfone_account.present?
      #search subaccount name in twilio & associate if not closed!
      create_freshfone_account
    end

    private

      def valid_request
        account.present?
      end

      def existing_freshfone_account
        account.freshfone_account
      end

      def subaccount_name
        "#{account.name.parameterize.underscore}_#{account.id}"
      end

      def host
      "#{account.url_protocol}://#{account.full_domain}"
      end

      def create_freshfone_account
        account_options = {
          :twilio_subaccount_id => sub_account.sid,
          :twilio_subaccount_token => sub_account.auth_token,
          :twilio_application_id => twilio_app.sid,
          :queue => queue.sid,
          :friendly_name => sub_account.friendly_name,
          :triggers => Freshfone::Account::TRIGGER_LEVELS_HASH.clone     
        }
        account_options[:state] = Freshfone::Account::STATE_HASH[:trial] if trial_params?
        account.create_freshfone_account(account_options)
      end

      def sub_account
        @sub_account ||= TwilioMaster.client.accounts.create({ :friendly_name => subaccount_name })
      end

      def twilio_app
        @application ||= sub_account.applications.create({
                        :friendly_name => account.name,
                        :voice_url => "#{host}/freshfone/voice", 
                        :voice_fallback_url => "#{host}/freshfone/voice_fallback"
                      })
      end

      def queue
        @queue ||= sub_account.queues.create(:friendly_name => account.name)
      end

  end
end
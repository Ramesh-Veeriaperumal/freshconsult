module AccountSetup
  extend ActiveSupport::Concern
  included do |base|
    base.extend  ClassMethods
    base.include  InstanceMethods
  end

  module ClassMethods
    def track_account_setup(*action_names)
      after_filter :complete_step, only: action_names, if: :setup_not_complete?
    end
  end

  module InstanceMethods
    def complete_step
      Rails.logger.debug "::::::: Trial widget update : #{current_setup_flag} set up :::::::"
      current_account.safe_send("mark_#{current_setup_flag}_setup_and_save")
    rescue Exception => e
      Rails.logger.debug "::::::: Trial widget account setup error : #{e}"
    end

    def setup_not_complete?
      response.code == '200' && current_account.subscription.trial? && 
        !current_account.safe_send("#{current_setup_flag}_setup?") && current_setup_flag_eligible?
    end

    def current_setup_flag
      @current_setup_flag ||= Account::Setup::CONTROLLER_SETUP_KEYS[params[:controller].split('/').last]
    end

    def current_setup_flag_eligible?
      return true unless respond_to?("#{current_setup_flag}_eligible?")
      safe_send("#{current_setup_flag}_eligible?")
    end

    def reports_eligible?
      false
    end  
  end
end

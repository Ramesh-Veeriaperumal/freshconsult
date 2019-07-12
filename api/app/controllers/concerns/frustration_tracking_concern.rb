module FrustrationTrackingConcern
  extend ActiveSupport::Concern
  include FreshmarketerConcern

  private

    def settings
      @settings ||= (cname_params && cname_params[:settings])
    end

    def freshmarketer
      @freshmarketer ||= cname_params[:freshmarketer]
    end

    def experiment_hash
      @experiment_hash ||= account_additional_settings.widget_predictive_support_hash
    end

    def predictive_support_toggled?
      settings.present? &&
        settings[:components].present? &&
        settings[:components].key?(:predictive_support)
    end

    def freshmarketer_integrate
      freshmarketer_client.link_account(email_or_domain, fm_link_type, domain || @item.settings[:predictive_support][:domain_list][0])
    end

    def email_or_domain
      freshmarketer[:email] || freshmarketer[:domain]
    end

    def fm_link_type
      freshmarketer[:type] == 'associate' ? 'associate_using_domain' : 'create'
    end

    def domain
      # An experiment is created for the first domain of the domain_list when freshmarketer account is created or link
      settings &&
        settings[:predictive_support] &&
        settings[:predictive_support][:domain_list] &&
        settings[:predictive_support][:domain_list][0]
    end

    def freshmarketer_signup
      return true unless cname_params.key?('freshmarketer')

      freshmarketer_integrate
      return false if client_error?

      cname_params.delete('freshmarketer')
    end

    def toggle_predictive_support(enabled = settings[:components][:predictive_support])
      if enabled
        @item.settings[:freshmarketer] = account_additional_settings.freshmarketer_settings_hash
      else
        unlink_freshmarketer
      end
      update_freshmarketer_domain(enabled)
    end

    def remove_predictive_cname_params
      settings.delete(:predictive_support) if settings && settings[:predictive_support]
    end

    def update_freshmarketer_domain(enabled)
      domain_list_to_update = begin
        if enabled
          param_domain_list.presence || db_domain_list
        else
          param_domain_list - db_domain_list
        end
      end
      domain_list_to_delete = begin
        if enabled
          param_domain_list.blank? ? [] : db_domain_list - param_domain_list
        else
          db_domain_list
        end
      end

      delete_or_update_experiment_list(domain_list_to_update, domain_list_to_delete, enabled)
    end

    def param_domain_list
      (settings &&
        settings[:predictive_support] &&
        settings[:predictive_support][:domain_list]) || []
    end

    def db_domain_list
      @db_domain_list ||= ((@item.settings[:predictive_support] && @item.settings[:predictive_support][:domain_list]) || [])
    end

    def delete_or_update_experiment_list(domain_list_to_update, domain_list_to_delete, predictive_support_enabled)
      domain_list_to_update.each do |domain|
        return false unless create_or_update_experiment(domain, predictive_support_enabled)
      end
      domain_list_to_delete.each do |domain|
        return false unless delete_experiment(domain)
      end
      account_additional_settings.additional_settings[:widget_predictive_support] = experiment_hash
      account_additional_settings.save
    end

    def create_or_update_experiment(domain, predictive_support_enabled)
      exp_id = experiment_hash && experiment_hash[domain] && experiment_hash[domain][:exp_id]
      return true unless predictive_support_enabled

      if exp_id
        update_experiment(exp_id)
      else 
        exp_id = freshmarketer_client.create_experiment(domain, true)
      end
      return false if client_error?

      experiment_hash[domain] = predictive_experiment_hash(domain, exp_id)
      true
    end

    def update_experiment(exp_id)
      freshmarketer_client.enable_integration(exp_id) &&
        freshmarketer_client.enable_predictive_support(exp_id)
    end

    def delete_experiment(domain)
      experiment = experiment_hash[domain]
      return if experiment.blank?

      experiment[:widget_ids].delete(@item.id)
      return true if experiment[:widget_ids].present?
      
      if account_additional_settings.freshmarketer_acc_id == experiment[:exp_id]
        freshmarketer_client.disable_predictive_support
      else
        freshmarketer_client.disable_integration(experiment[:exp_id])
      end
    end

    def downcase_domain_list
      return if param_domain_list.blank?

      settings[:predictive_support][:domain_list] = param_domain_list.map!(&:downcase).uniq
    end

    def predictive_experiment_hash(domain, exp_id)
      experiment = experiment_hash[domain]
      {
        exp_id: exp_id,
        widget_ids: ((experiment && experiment[:widget_ids] || []) << @item.id).uniq
      }
    end

    def unlink_freshmarketer
      @item.settings[:components][:predictive_support] = false
      @item.settings.delete(:freshmarketer)
    end
end

module PredictiveSupportConcern
  extend ActiveSupport::Concern

  private

    def additional_settings
      @additional_settings ||= Account.current.account_additional_settings_from_cache
    end

    def experiment_hash
      @experiment_hash ||= additional_settings.widget_predictive_support_hash
    end

    def toggle_predictive_support(enabled = true)
      if enabled
        @item.settings[:freshmarketer] = additional_settings.freshmarketer_settings_hash
      else
        unlink_freshmarketer
      end
      update_freshmarketer_domain(enabled)
    end

    def remove_predictive_cname_params
      cname_params[:settings].delete(:predictive_support)
    end

    def update_freshmarketer_domain(enabled)
      domain_list_to_update = begin
        if predictive_enabled?
          param_domain_list.blank? ? db_domain_list : param_domain_list
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

      delete_or_update_experiment_list(domain_list_to_update, domain_list_to_delete)
    end

    def param_domain_list
      @param_domain_list ||= begin
        (cname_params &&
          cname_params[:settings] &&
          cname_params[:settings][:predictive_support] &&
          cname_params[:settings][:predictive_support][:domain_list]) || []
      end
    end

    def db_domain_list
      @db_domain_list ||= ((@item.settings[:predictive_support] && @item.settings[:predictive_support][:domain_list]) || [])
    end

    def delete_or_update_experiment_list(domain_list_to_update, domain_list_to_delete)
      domain_list_to_update.each do |domain|
        return false unless create_or_update_experiment(domain)
      end
      domain_list_to_delete.each do |domain|
        return false unless delete_experiment(domain)
      end
      additional_settings.additional_settings[:widget_predictive_support] = experiment_hash
      additional_settings.save
    end

    def create_or_update_experiment(domain)
      exp_id = experiment_hash[domain] && experiment_hash[domain][:exp_id]
      
      if exp_id
        update_experiment(exp_id)
      else
        exp_id = freshmarketer_client.create_experiment(domain)
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

      if additional_settings.freshmarketer_acc_id == experiment[:exp_id]
        freshmarketer_client.disable_predictive_support
      else
        freshmarketer_client.disable_integration(experiment[:exp_id])
      end
    end

    def downcase_domain_list
      return if param_domain_list.blank?

      cname_params[:settings][:predictive_support][:domain_list] = param_domain_list.map!(&:downcase).uniq
    end

    def predictive_experiment_hash(domain, exp_id)
      experiment = experiment_hash[domain]
      {
        exp_id: exp_id,
        widget_ids: ((experiment && experiment[:widget_ids] || []) << @item.id).uniq
      }
    end

    def freshmarketer_client
      @freshmarketer_client ||= ::Freshmarketer::Client.new
    end

    def client_error?
      freshmarketer_client.response_code != :ok
    end

    def unlink_freshmarketer
      @item.settings[:components][:predictive_support] = false
      @item.settings.delete(:freshmarketer)
    end

    def freshmarketer_details
      additional_settings.freshmarketer_linked? ? { freshmarketer_name: additional_settings.freshmarketer_name } : {}
    end

    def predictive_support_toggled?
      cname_params &&
        cname_params[:settings] &&
        cname_params[:settings][:components] &&
        cname_params[:settings][:components].key?(:predictive_support)
    end

    def predictive_enabled?
      predictive_support_toggled? && cname_params[:settings][:components][:predictive_support]
    end
end

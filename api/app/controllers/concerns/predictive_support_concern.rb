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
      cname_domain_list = domain_list_from_param
      db_domain_list = domain_list_from_db
      cname_domain_list_sub = cname_domain_list.present? ? sub_domain_list(cname_domain_list) : []
      domain_list_to_update = cname_domain_list_sub.presence || db_domain_list
      domain_list_to_delete = enabled ? [] : db_domain_list

      if db_domain_list.present? && cname_domain_list_sub.present?
        domain_list_to_update = cname_domain_list_sub - db_domain_list unless predictive_enabled?
        domain_list_to_delete = db_domain_list - cname_domain_list_sub
      end
      delete_or_update_experiment_list(domain_list_to_update, domain_list_to_delete)
    end

    def domain_list_from_param
      cname_params &&
        cname_params[:settings] &&
        cname_params[:settings][:predictive_support] &&
        cname_params[:settings][:predictive_support][:domain_list]
    end

    def domain_list_from_db
      db_domain_exist? ? sub_domain_list(@item.settings[:predictive_support][:domain_list]) : []
    end

    def db_domain_exist?
      @item.settings.key?(:predictive_support) &&
        @item.settings[:predictive_support][:domain_list].present?
    end

    def delete_or_update_experiment_list(domain_list_to_update, domain_list_to_delete)
      if domain_list_to_update.present?
        return false unless update_experiment_hash(domain_list_to_update)
      end
      if domain_list_to_delete.present?
        return false unless delete_domain_list(domain_list_to_delete)
      end
      additional_settings.additional_settings[:widget_predictive_support] = experiment_hash
      additional_settings.save
    end

    def update_experiment_hash(domain_list_to_update)
      domain_list_to_update.each do |domain|
        return false unless create_or_update_experiment(domain)
      end
    end

    def create_or_update_experiment(domain)
      experiment = experiment_hash[domain]
      if experiment
        return false unless update_experiment(experiment)

        experiment_hash[domain] = experiment
      else
        exp_result = freshmarketer_client.create_experiment(domain)
        return false unless exp_result.is_a?(::Hash) && exp_result[:status].presence

        experiment_hash[domain] = predictive_experiment_hash(exp_result[:exp_id])
      end
      true
    end

    def update_experiment(experiment)
      return false unless freshmarketer_client.enable_predictive_integration(experiment[:exp_id])

      return false unless freshmarketer_client.enable_predictive_support(experiment[:exp_id])

      experiment[:widget_ids] << @item.id unless experiment[:widget_ids].include?(@item.id)
      true
    end

    def delete_domain_list(domain_list_to_delete)
      domain_list_to_delete.each do |domain|
        experiment = experiment_hash[domain]
        next if experiment.blank?

        experiment[:widget_ids].delete(@item.id)
        next if experiment[:widget_ids].present?

        if additional_settings.freshmarketer_acc_id == experiment[:exp_id]
          return false unless freshmarketer_client.disable_predictive_support
        else
          return false unless freshmarketer_client.disable_predictive_integration(experiment[:exp_id])
        end
      end
      true
    end

    def sub_domain(domain)
      sub_dmn = domain.split('.')
      return domain if sub_dmn.length <= 2

      domain[sub_dmn[0].length + 1, domain.length]
    end

    def sub_domain_list(domain_list)
      ret_list = []
      domain_list.each do |domain|
        sub_d = sub_domain(domain)
        ret_list << sub_d unless ret_list.include?(sub_d)
      end
      ret_list
    end

    def downcase_domain_list
      domain_list = domain_list_from_param
      return if domain_list.blank?

      cname_params[:settings][:predictive_support][:domain_list] = domain_list.map!(&:downcase).uniq
    end

    def predictive_experiment_hash(exp_id)
      {
        exp_id: exp_id,
        widget_ids: [@item.id]
      }
    end

    def freshmarketer_client
      @freshmarketer_client ||= ::Freshmarketer::Client.new
    end

    def unlink_freshmarketer
      @item.settings[:components][:predictive_support] = false
      @item.settings.delete(:freshmarketer)
    end

    def freshmarketer_details
      additional_settings.freshmarketer_linked? ? { freshmarketer_name: additional_settings.freshmarketer_name } : {}
    end

    def predictive_support_toggled?
      cname_params[:settings] &&
        cname_params[:settings][:components] &&
        cname_params[:settings][:components].key?(:predictive_support)
    end

    def predictive_enabled?
      predictive_support_toggled? && cname_params[:settings][:components][:predictive_support]
    end
end

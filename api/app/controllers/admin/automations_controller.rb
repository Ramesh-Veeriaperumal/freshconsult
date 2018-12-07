class Admin::AutomationsController < ApiApplicationController
  include HelperConcern
  include Admin::AutomationConstants

  ROOT_KEY = :rule
  decorate_views(decorate_objects: [:index])

  def index
    super
    response.api_meta = {
      count: @items_count,
      cascading_rules: current_account.features?(:cascade_dispatchr)
    }
  end

  private

    def scoper
      rule_type = VAConfig::RULES_BY_ID[params[:rule_type].to_i]
      rule_association = VAConfig::ASSOCIATION_MAPPING[rule_type]
      current_account.safe_send("all_#{rule_association}".to_sym) unless rule_association.nil?
    end

    def validate_filter_params(_additional_fields = [])
      validate_query_params
    end

    def load_object(items = scoper)
      @item = items.find_by_id(params[:id]) unless items.nil?
      log_and_render_404 unless @item
    end

    def constants_class
      Admin::AutomationConstants.to_s.freeze
    end
    
    def launch_party_name
      FeatureConstants::AUTOMATION_REVAMP
    end

end

class HelpWidgetDelegator < BaseDelegator
  include ActiveRecord::Validations

  attr_accessor :settings, :components, :predictive_support, :freshmarketer

  validate :validate_product, if: -> { @product_id }
  validate :check_appearance, if: -> { @settings.present? && @settings[:appearance].present? }
  validate :check_predictive_support, if: -> { predictive_support_present? || @freshmarketer.present? }
  validate :validate_widget_flow, if: -> { @settings.present? && @settings[:widget_flow].present? }
  validate :validate_domain_list, if: -> { @settings.present? && domain_list_or_predictive }
  validate :validate_frustration_tracking, if: -> { errors.blank? && predictive_support_present? && @freshmarketer.blank? }, on: :update
  validate :validate_freshmarketer, if: -> { errors.blank? && @freshmarketer.present? }, on: :update

  def initialize(record, options = {})
    @item = record
    @product_id = options[:product_id]
    @settings = options[:settings]
    @components = options[:settings][:components] if settings
    @predictive_support = options[:settings][:predictive_support] if settings
    @freshmarketer = options[:freshmarketer]
    @error_options ||= {}
  end

  def validate_product
    product_ids = Account.current.products_from_cache.collect(&:id)
    unless product_ids.include?(@product_id)
      errors[:product_id] << :inaccessible_value
    end
  end

  def validate_widget_flow
    unless contact_form_enabled && solution_articles_enabled
      errors[:widget_flow] << :inaccessible_field
    end
  end

  def validate_domain_list
    if predictive_support_enabled && domain_list_blank
      errors[:domain_list] << I18n.t('help_widget.domain_list_empty')
    end
  end

  def validate_frustration_tracking
    errors[:predictive_support_hash] << I18n.t('help_widget.invalid_components', key: 'predictive_support') unless freshmarketer_linked?
  end

  def validate_freshmarketer
    validate_domain if freshmarketer[:type] == 'associate'
    errors[:predictive_support] << I18n.t('help_widget.freshmarketer_sign_up_error') if components && !components[:predictive_support]
  end

  def check_appearance
    required_feature_error(:appearance, :help_widget_appearance) unless Account.current.help_widget_appearance_enabled?
  end

  def check_predictive_support
    required_feature_error(:predictive_support, :help_widget_predictive) unless Account.current.help_widget_predictive_enabled?
  end

  private

    def contact_form_enabled
      if components && components.key?('contact_form')
        components[:contact_form]
      else
        @item.contact_form_enabled?
      end
    end

    def solution_articles_enabled
      if components && components.key?('solution_articles')
        components[:solution_articles]
      else
        @item.solution_articles_enabled?
      end
    end

    def predictive_support_enabled
      if components && components.key?(:predictive_support)
        components[:predictive_support]
      else
        @item.predictive?
      end
    end

    def validate_domain
      freshmarketer_client = ::Freshmarketer::Client.new
      valid_domains = freshmarketer_client.domains
      errors[:freshmarketer_domain] << I18n.t('help_widget.invalid_components') if valid_domains['domains'].exclude?(freshmarketer[:domain])
    end

    def domain_list_blank
      if predictive_support && predictive_support.key?(:domain_list)
        predictive_support[:domain_list].blank?
      else
        @item.settings[:predictive_support].blank? || @item.settings[:predictive_support][:domain_list].blank?
      end
    end

    def domain_list_or_predictive
      (predictive_support && predictive_support.key?(:domain_list)) ||
        (components && components.key?(:predictive_support))
    end

    def freshmarketer_linked?
      account_additional_settings = Account.current.account_additional_settings
      account_additional_settings && account_additional_settings.additional_settings[:freshmarketer].present?
    end

    def predictive_support_present?
      settings && (predictive_support || (components && components.key?(:predictive_support)))
    end

    def required_feature_error(field, feature)
      errors[field] << :require_feature
      @error_options[:feature] = feature
    end
end

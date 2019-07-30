class Admin::CustomTranslationsController < ApiApplicationController
  include HelperConcern

  before_filter :check_launch_party_feature
  before_filter :validate_query_params, only: [:download]
  before_filter :set_scope, only: [:download]

  def download
    @language = Account.current.language
    translation = { @language => { 'custom_translations' => fetch_translation } }
    respond_with_yaml(translation)
  end

  private

    def fetch_translation
      data = {}
      @objects.each do |object|
        items = params['object_id'].blank? ? scoper(object) : scoper(object).where(id: params['object_id'])
        data[object] = {}
        items.each do |item|
          data[object][item.custom_translation_key] = item.as_api_response(download_type).stringify_keys
        end
      end
      data
    end

    def respond_with_yaml(translation)
      response.headers['Content-Disposition'] = "attachment; filename=#{@language}.yml"
      render text: translation.psych_to_yaml, content_type: 'text/yaml'
    end

    def download_type
      :custom_translation
    end

    def constants_class
      'Admin::CustomTranslationsConstants'.freeze
    end

    def scoper(object)
      object_mapping = Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object]
      items = Account.current.safe_send(object_mapping[:model])
      items.where(object_mapping[:conditions]) if object_mapping[:conditions].present?
    end

    def set_scope
      @objects = params['object_type'].present? ? [params['object_type']] : Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS.keys
    end

    def feature_name
      :custom_translations
    end

    def check_launch_party_feature
      return if Account.current.csat_translations_enabled?

      render_request_error(:require_feature, 403, feature: 'csat_translations'.titleize)
    end
end

class Admin::CustomTranslationsController < ApiApplicationController
  include HelperConcern

  before_filter :check_launch_party_feature
  before_filter :validate_query_params, only: [:download]
  before_filter :validate_upload_params, only: [:upload]
  before_filter :set_scope

  WRAP_PARAMS = [:custom_translation, exclude: [], format: [:multipart_form]].freeze

  def upload
    translation_file = cname_params['translation_file']
    translation_file = translation_file.is_a?(StringIO) ? translation_file : translation_file.tempfile
    tf_hash = YAML.safe_load(translation_file)
    @language = Language.find_by_code(params['language_code'])
    custom_translations_hash = tf_hash[@language.code]['custom_translations']
    upload_translation(custom_translations_hash) unless custom_translations_hash.empty?

    head 202
  end

  def download
    translation = { @language => { 'custom_translations' => fetch_translation } }
    respond_with_yaml(translation)
  end

  private

    def check_launch_party_feature
      return if Account.current.csat_translations_enabled?

      render_request_error(:require_feature, 403, feature: 'csat_translations'.titleize)
    end

    def fetch_translation
      data = {}
      @objects.each do |object|
        items = params['object_id'].blank? ? scoper(object) : scoper(object).where(id: params['object_id'])
        items = items.preload("#{@language.underscore}_translation".to_sym) if download_type == :custom_translation_secondary
        data[object] = {}
        items.each do |item|
          data[object][item.custom_translation_key] = item.as_api_response(download_type, lang: @language).stringify_keys
        end
      end
      data
    end

    def feature_name
      :custom_translations
    end

    def valid_content_type?
      return true if request.content_mime_type.blank?

      allowed_content_types = Admin::CustomTranslationsConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def cname
      'custom_translation'.freeze
    end

    def validate_upload_params
      params_hash = cname_params.merge(language_code: params['language_code'], object_type: params['object_type'], object_id: params['object_id']) if cname_params.present?
      return unless validate_query_params(nil, params_hash)
    end

    def download_type
      @language == Account.current.language ? :custom_translation : :custom_translation_secondary
    end

    def constants_class
      'Admin::CustomTranslationsConstants'.freeze
    end

    def scoper(object)
      object_mapping = Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object]
      items = Account.current.safe_send(object_mapping[:model])
      items = items.where(object_mapping[:conditions]) if object_mapping[:conditions].present?
      items
    end

    def set_scope
      @language = params['language_code'] || Account.current.language
      @objects = params['object_type'].present? ? [params['object_type']] : Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS.keys
    end

    # if the object is empty, upload for all the modules
    # if the object is present, even if the file has entries for all modules, upload only for given object
    # if the object & record id is present & upload only for the particular record
    # Below method will be added to helper & used in the sidekiq worker.
    # Below method is having an assumption that in upload file module name will be surveys &
    # each record name will be survey_*

    def upload_translation(translations)
      object_id = params['object_id']

      @objects.each do |object|
        items = object_id.blank? ? scoper(object) : scoper(object).where(lookup_method(object) => object_id).first

        if object_id
          record_key = translations[object][items.custom_translation_key]
          create_translation(items, record_key) if record_key.present?
        end
      end
    end

    def lookup_method(object)
      Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS[object][:lookup_key]
    end

    def create_translation(field_object, translations)
      custom_translation = field_object.safe_send(language_translation)

      if custom_translation.blank?
        field_object.safe_send("build_#{language_translation}", translations: translations).save!
      else
        custom_translation.update_attributes(translations: translations)
      end
    end

    def language_translation
      "#{@language.to_key}_translation"
    end

    # Adding code for file upload in S3.
    # Temporarily commenting it. Will need it when we use workers to do the upload processing.
    # def save_yml(cname_params, id)
    #   translation_file = cname_params['translation_file']
    #   return nil if translation_file.nil?

    #   translation_file = translation_file.is_a?(StringIO) ? translation_file : translation_file.tempfile
    #   file_path = generate_file_path(id)
    #   AwsWrapper::S3Object.store(file_path,
    #                              translation_file,
    #                              S3_CONFIG[:bucket],
    #                              server_side_encryption: :aes256, expires: 30.days)
    #   file_path
    # end

    # def generate_file_path(language)
    #   output_dir = "data/helpdesk/custom_translations/#{Rails.env}/#{Account.current.id}"
    #   file_path = "#{output_dir}/#{language}-#{Time.now.utc.strftime('%B-%d-%Y-%H:%M:%S')}.yml"
    #   file_path
    # end

    def respond_with_yaml(translation)
      response.headers['Content-Disposition'] = "attachment; filename=#{@language}.yml"
      render text: translation.psych_to_yaml, content_type: 'text/yaml'
    end

    wrap_parameters(*WRAP_PARAMS)
end

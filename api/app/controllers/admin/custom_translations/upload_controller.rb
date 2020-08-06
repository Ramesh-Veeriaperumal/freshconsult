# Controller to upload custom translations for fields
class Admin::CustomTranslations::UploadController < ApiApplicationController
  skip_before_filter :before_load_object, :load_object, :after_load_object

  WRAP_PARAMS = [:custom_translation, exclude: [], format: [:multipart_form]].freeze

  def upload
    return unless validate_params

    file_path = save_yml(cname_params, params['id'])
    Admin::CustomTranslations::Upload.perform_async(file_path, params['id']) unless file_path.nil?
    head 202
  end

  private

    def feature_name
      :custom_translations
    end

    def cname
      'custom_translation'.freeze
    end

    def validate_params
      field = ['translation_file']
      params[cname].permit(*field)
      upload_validation = Admin::CustomTranslations::UploadValidation.new(translation_file: cname_params['translation_file'], language_code: params['id'])
      valid = upload_validation.valid?
      render_errors upload_validation.errors, upload_validation.error_options unless valid
      valid
    end

    def save_yml(cname_params, id)
      translation_file = cname_params['translation_file']
      return nil if translation_file.nil?

      translation_file = translation_file.is_a?(StringIO) ? translation_file : translation_file.tempfile
      file_path = generate_file_path(id)
      AwsWrapper::S3.put(S3_CONFIG[:bucket], file_path, translation_file, server_side_encryption: 'AES256', expires: (Time.now + 30.days))
      file_path
    end

    def valid_content_type?
      return true if request.content_mime_type.nil?

      request.content_mime_type.try(:ref) == :multipart_form
    end

    def generate_file_path(language)
      output_dir = "data/helpdesk/custom_translations/#{Rails.env}/#{Account.current.id}"
      file_path = "#{output_dir}/#{language}-#{Time.now.utc.strftime('%B-%d-%Y-%H:%M:%S')}.yml"
      file_path
    end

    wrap_parameters(*WRAP_PARAMS)
end

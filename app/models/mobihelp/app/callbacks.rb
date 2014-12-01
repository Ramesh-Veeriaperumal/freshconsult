class Mobihelp::App < ActiveRecord::Base

  before_create       :set_key_and_secret
  after_initialize    :fix_config
  before_validation   :remove_white_space
  after_commit        :clear_app_cache, :clear_mobihelp_solutions_cache

  private

    def set_key_and_secret
      require 'digest/sha1'
      require 'digest/md5'

      unique_digest_str = Digest::MD5.hexdigest("#{name}-#{PLATFORM_NAMES_BY_ID[platform]}-#{account_id}-#{Time.now}")
      digest_str = (rand(Digest::MD5.hexdigest(unique_digest_str).to_i(16)) ^ rand(Digest::MD5.hexdigest(unique_digest_str).to_i(16))).to_s
      digest_str= Digest::SHA1.hexdigest(digest_str).strip.gsub("=" ,"")
      self.app_key = "#{name.downcase.squish.gsub(" ","")}-#{platform}-#{unique_digest_str}"
      self.app_secret = digest_str
    end

    def fix_config
      if config.nil?
        self.config ||= default_values # set default values if it is nil
      else
        if platform == PLATFORM_ID_BY_KEY[:android] && !push_notification_enabled?
          self.config[:gcm_api_key] = ""
        end
      end
    end

    def remove_white_space
      self.name.strip!
    end

    def default_values
      default_config = {
        :solutions => "",
        :push_notification => 'false',
      }
      default_config[:app_store_id] = "" if platform == PLATFORM_ID_BY_KEY[:ios]
      default_config
    end

    def clear_mobihelp_solutions_cache
      clear_solutions_cache(self.config[:solutions].to_i)
    end
end

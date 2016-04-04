module Solution::UrlSterilize

  FILE_PATH = "#{Rails.root}/config/url_sterilize.yml"
  BLACKLIST = YAML.load(File.read(File.expand_path(FILE_PATH, __FILE__))).symbolize_keys

  def sterilize(str)
    return "" if str.blank? || !str.is_a?(String)
    str.split('').map { |char| replace_and_remove(char) }.join()
  end

  private

    def get_unicode(char)
      "%4.4x"%char.ord.to_s
    end

    def replace_and_remove(char)
      unicode_val = get_unicode(char)

      if BLACKLIST[:remove].include?(unicode_val)
        "_" 
      elsif BLACKLIST[:replace_equivalent].keys.include?(unicode_val) 
        BLACKLIST[:replace_equivalent][unicode_val]
      else 
        char
      end
    end

end
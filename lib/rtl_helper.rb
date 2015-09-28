module RtlHelper

  RTL_LANGUAGES = %w( ar he )

  def is_current_language_rtl? lang = I18n.locale.to_s
    RTL_LANGUAGES.include? lang
  end

  def current_direction?
    is_current_language_rtl? ? "rtl" : "ltr"
  end

  def stylesheet_link_tag_with_rtl(*packages)
    options = packages.extract_options!

    packages.uniq.map { |package|
      
      package_name = is_current_language_rtl? ? package.to_s.gsub("cdn/","cdn/rtl/") : package

      stylesheet_link_tag package_name.to_sym, options 

    }.join("").html_safe
  end

end
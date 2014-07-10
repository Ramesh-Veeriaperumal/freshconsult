class Mobihelp::App < ActiveRecord::Base

  validate :validates_config
  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false, :scope => [:account_id, :platform]
  validates_inclusion_of :platform, :in => PLATFORM_ID_BY_KEY.values

  #Validates if the config has valid hash values before saving
  def validates_config
    if config
      bread_crumbs = CONFIGURATIONS[:bread_crumbs].include? config[:bread_crumbs]
      debug_log_count = CONFIGURATIONS[:debug_log_count].include? config[:debug_log_count]
      if !bread_crumbs
        errors.add(I18n.t('admin.mobihelp.apps.form.bread_crumbs'), I18n.t('admin.mobihelp.apps.form.not_included'))
      elsif !debug_log_count
        errors.add(I18n.t('admin.mobihelp.form.debug_log_count'), I18n.t('admin.mobihelp.form.not_included'))
      else
        {}
      end
    end
  end
end

module Helpdesk

  def self.prepare(params) 
    if params.is_a?(Hash)
      params.symbolize_keys!
      params.each { |k, v| params[k] = self.prepare(v) }
    end
    return params 
  end
end

YAML.load_file("#{Rails.root}/config/helpdesk.yml").each do |k, v|
  Helpdesk.const_set(k.upcase, Helpdesk::prepare(v))
end

if Helpdesk::EMAIL[:outgoing] && Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
  ActionMailer::Base.smtp_settings = Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
end

#I18n fallbacks if the it doesn't exists in a prticular language
I18n.backend.class.send(:include, I18n::Backend::Fallbacks)
I18n.fallbacks.map('it' => 'en')
I18n.fallbacks.map('es' => 'en')
I18n.fallbacks.map('de' => 'en')
I18n.fallbacks.map('fr' => 'en')
I18n.fallbacks.map('nl' => 'en')
I18n.fallbacks.map('pl' => 'en')
I18n.fallbacks.map('pt-BR' => 'en')
I18n.fallbacks.map('pt-PT' => 'en')
I18n.fallbacks.map('fi' => 'en')
I18n.fallbacks.map('ru-RU' => 'en')
I18n.fallbacks.map('zh-CN' => 'en')
I18n.fallbacks.map('ja-JP' => 'en')
I18n.fallbacks.map('da' => 'en')
I18n.fallbacks.map('sl' => 'en')
I18n.fallbacks.map('es-LA' => 'en')
I18n.fallbacks.map('nb-NO' => 'en')
I18n.fallbacks.map('tr' => 'en')
I18n.fallbacks.map('sk' => 'en')
I18n.fallbacks.map('ca' => 'en')
I18n.fallbacks.map('id' => 'en')
I18n.fallbacks.map('vi' => 'en')
I18n.fallbacks.map('ko' => 'en')
I18n.fallbacks.map('hu' => 'en')

#For importing google contacts lazily from delayed jobs and also using rails recipes.
Integrations::GoogleContactsImporter
Integrations::GoogleContactsUtil
Integrations::GoogleAccount

#ActiveRecord::Base.default_shard = ActiveRecord::Base.shard_names.first


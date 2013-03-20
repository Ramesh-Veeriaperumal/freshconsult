module Helpdesk

  def self.prepare(params) 
    if params.is_a?(Hash)
      params.symbolize_keys!
      params.each { |k, v| params[k] = self.prepare(v) }
    end
    return params 
  end
end

YAML.load_file("#{RAILS_ROOT}/config/helpdesk.yml").each do |k, v|
  Helpdesk.const_set(k.upcase, Helpdesk::prepare(v))
end

if Helpdesk::EMAIL[:outgoing] && Helpdesk::EMAIL[:outgoing][RAILS_ENV.to_sym]
  ActionMailer::Base.smtp_settings = Helpdesk::EMAIL[:outgoing][RAILS_ENV.to_sym]
end

#For sending exception notifications 
ExceptionNotification::Notifier.exception_recipients = %w(support@freshdesk.com) if RAILS_ENV == "production"
ExceptionNotification::Notifier.exception_recipients = %w(vijay@freshdesk.com) if RAILS_ENV == "staging"
ExceptionNotification::Notifier.sender_address =  %("Freshdesk Error" <rachel@freshdesk.com>)

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

#For importing google contacts lazily from delayed jobs and also using rails recipes.
Integrations::GoogleContactsImporter
Integrations::GoogleContactsUtil
Integrations::GoogleAccount


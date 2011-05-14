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

I18n.backend.class.send(:include, I18n::Backend::Fallbacks)
I18n.fallbacks.map('it' => 'en')
I18n.fallbacks.map('es' => 'en')
I18n.fallbacks.map('de' => 'en')
I18n.fallbacks.map('fr' => 'en')



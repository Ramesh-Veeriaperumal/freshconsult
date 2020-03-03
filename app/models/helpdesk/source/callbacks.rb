class Helpdesk::Source < Helpdesk::Choice
  before_destroy :check_if_default

  private

    def check_if_default
      if default?
        errors.add(:base, I18n.t('cannot_delete_default_source'))
        false
      end
    end
end

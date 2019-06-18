class PrimaryLanguageChange
  include Sidekiq::Worker

  sidekiq_options queue: :primary_language_change, retry: 0,  failures: :exhausted

  SOLUTION_CLASSES = ["Solution::Category", "Solution::Folder", "Solution::Article"]

  SOLUTION_MODELS = {
    :solution_category_meta => [:solution_categories],
    :solution_folder_meta => [:solution_folders],
    :solution_article_meta => [:solution_articles, :draft]
  }

  def perform(args)
    args.symbolize_keys!
    begin
      delete_secondary_translations
      change_main_portal_language(args[:language])
      clear_supported_languages
      Community::HandleLanguageChange.new.perform
      Community::SolutionBinarizeSync.new.perform
      Account.current.features.enable_multilingual.destroy
      ::Admin::LanguageMailer.send(:primary_language_change, args[:email], args[:language_name])
    rescue => e
      Rails.logger.error("Exception in primary language change for account #{Account.current.id} :: #{e.inspect}")
      NewRelic::Agent.notice_error(e, description: "Exception in primary language change for account #{Account.current.id}")
    end
  end

  private

    def delete_secondary_translations
      SOLUTION_MODELS.keys.each do |sol_assoc|
        Account.current.send(sol_assoc).find_each(batch_size: 200) do |sol_parent|
          sol_parent.children.each do |sol_child|
            sol_child.destroy unless sol_child.is_primary?
          end
        end
      end
    end

    def change_main_portal_language(language)
      Account.current.main_portal.language = language
      Account.current.main_portal.save
    end

    def clear_supported_languages
      Account.current.account_additional_settings.supported_languages = []
      Account.current.account_additional_settings.save
    end
end
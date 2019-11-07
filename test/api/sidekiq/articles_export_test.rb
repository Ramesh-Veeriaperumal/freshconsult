require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'

Sidekiq::Testing.fake!

require Rails.root.join('spec', 'support', 'agent_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'search_test_helper.rb')
require Rails.root.join('spec', 'support', 'solution_builder_helper.rb')
require Rails.root.join('spec', 'support', 'solutions_helper.rb')

class ArticlesExportTest < ActionView::TestCase
  include AgentHelper
  include SolutionsHelper
  include SolutionBuilderHelper

  def setup
    super
    @account ||= Account.first.make_current
    @agent = @account.agents.first || add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
    stub_request(:post, %r{^http://scheduler-staging.freshworksapi.com/schedules.*?$}).to_return(status: 200, body: '', headers: {})
  end

  def test_export_articles_csv
    setup_article
    cname_params = { status: 1, portal_id: Account.current.main_portal.id.to_s, category: [@category_meta.id.to_s], folder: [@folder_meta.id.to_s] }
    args = {
      filter_params: cname_params,
      lang_id: @account.language_object.id,
      current_user_id: @agent.user_id,
      export_fields: { id: 'ID', title: 'Title' },
      portal_url: 'localhost.freshdesk-dev.com'
    }
    Export::Util.stubs(:build_attachment).returns(true)
    DataExportMailer.expects(:send_email).times(1)
    Export::Article.expects(:send_no_article_email).times(0)

    Articles::Export::ArticlesExport.new.perform(args)

    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:article]
    assert_equal data_export.last_error, nil
    data_export.destroy
    tear_down
  ensure
    Export::Util.unstub(:build_attachment)
  end

  def test_export_articles_with_no_articles_csv
    cname_params = { status: 1, portal_id: Account.current.main_portal.id.to_s, category: ['cat'], folder: ['fol'] }
    args = {
      filter_params: cname_params,
      lang_id: @account.language_object.id,
      current_user_id: @agent.user_id,
      export_fields: { id: 'ID', title: 'Title' },
      portal_url: 'localhost.freshdesk-dev.com'
    }
    Export::Util.stubs(:build_attachment).returns(true)
    DataExportMailer.expects(:send_email).times(1)

    Articles::Export::ArticlesExport.new.perform(args)
  ensure
    Export::Util.unstub(:build_attachment)
  end

  def setup_article
    lang_hash = { lang_codes: @account.supported_languages + ['primary'] }
    @category_meta = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
    @folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: @category_meta.id)

    @articlemeta = Solution::ArticleMeta.new
    @articlemeta.art_type = 1
    @articlemeta.solution_folder_meta_id = @folder_meta.id
    @articlemeta.solution_category_meta = @folder_meta.solution_category_meta
    @articlemeta.account_id = @account.id
    @articlemeta.published = false
    @articlemeta.save!

    @article_with_lang = Solution::Article.new
    @article_with_lang.title = 'Test Article'
    @article_with_lang.description = '<b>test</b>'
    @article_with_lang.status = 1
    @article_with_lang.language_id = @account.language_object.id
    @article_with_lang.parent_id = @articlemeta.id
    @article_with_lang.account_id = @account.id
    @article_with_lang.user_id = @account.agents.first.id
    @article_with_lang.save!
  end

  def article_params(options = {})
    lang_hash = { lang_codes: options[:lang_codes] }
    category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
    {
      title: options[:title] || 'Test',
      description: 'Test',
      folder_meta: create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)),
      status: options[:status] || Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    }.merge(lang_hash)
  end

  def tear_down
    @article_with_lang.destroy if @article_with_lang
    @articlemeta.destroy if @articlemeta
    @folder_meta.destroy if @folder_meta
    @category_meta.destroy if @category_meta
  end
end

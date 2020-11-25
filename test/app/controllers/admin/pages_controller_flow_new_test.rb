# frozen_string_literal: true

require_relative '../../../api/api_test_helper'
require_relative '../../../../spec/support/ticket_helper'

class Admin::PagesControllerFlowTest < ActionDispatch::IntegrationTest
  include TicketHelper
  def setup
    super
    @page_type_array = []
    Portal::Page::PAGE_GROUPS.each do |group_hash|
      group_hash.each do |_key, group|
        group.each do |page|
          @page_type_array << Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[page]
        end
      end
    end
  end

  def test_update_portal_page
    page_type = @page_type_array.sample
    portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[page_type]
    page = @account.main_portal.template.pages.new(page_type: page_type)
    new_content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub('h2', 'h4')
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}", portal_page: { page_type: page_type, content: new_content }
    end
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_instance_of(Portal::Page, cached_page)
    assert_equal cached_page.content, new_content
  end

  def test_update_restricted_portal_page
    restricted_page_type = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[Portal::Page::RESTRICTED_PAGES.sample]
    portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[restricted_page_type]
    page = @account.main_portal.template.pages.new(page_type: restricted_page_type)
    new_content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub('h2', 'h4')
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{restricted_page_type}", portal_page: { page_type: restricted_page_type, content: new_content }
    end
    assert session['flash'][:warning].include?('You are not allowed to access this page!')
    assert_response 302
    assert_redirected_to support_login_url
  end

  def test_update_portal_page_and_publish
    page_type = @page_type_array.sample
    portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[page_type]
    page = @account.main_portal.template.pages.new(page_type: page_type)
    new_content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub('h2', 'h4')
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}", portal_page: { page_type: page_type, content: new_content }, publish_button: 'Save and Publish'
    end
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_nil cached_page
    @account.reload
    assert_equal(@account.portal_pages.find_by_page_type(page_type).content, new_content)
    assert_equal session['flash'][:notice], 'Portal changes published successfully.'
  end

  def test_update_portal_page_and_preview_ticket_view
    portal_page_label = :ticket_view
    page_type = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[portal_page_label]
    page = @account.main_portal.template.pages.new(page_type: page_type)
    new_content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub('h2', 'h4')
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}", portal_page: { page_type: page_type, content: new_content }, preview_button: 'Preview'
    end
    assert_response 302
    assert_equal flash[:error], "No tickets to preview. <a href='http://localhost.freshpo.com/support/tickets/new' target='_blank'>+ Create ticket</a>"
    assert_redirected_to 'http://localhost.freshpo.com/support/preview'
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_instance_of(Portal::Page, cached_page)
    assert_equal(cached_page.content, new_content)
  end

  def test_update_portal_page_and_preview_redirect_solution_home
    portal_page_label = :solution_home
    page_type = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[portal_page_label]
    page = @account.main_portal.template.pages.new(page_type: page_type)
    new_content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub('h2', 'h4')
    ticket = create_ticket(requester_id: User.current.id)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}", portal_page: { page_type: page_type, content: new_content }, preview_button: 'Preview'
    end
    assert_response 302
    assert_redirected_to 'http://localhost.freshpo.com/support/preview'
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_instance_of(Portal::Page, cached_page)
    assert_equal(cached_page.content, new_content)
    ticket.delete
  end

  def test_update_portal_page_and_preview_redirect_ticket_view
    portal_page_label = :ticket_view
    page_type = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[portal_page_label]
    page = @account.main_portal.template.pages.new(page_type: page_type)
    new_content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub('h2', 'h4')
    ticket = create_ticket(requester_id: User.current.id)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}", portal_page: { page_type: page_type, content: new_content }, preview_button: 'Preview'
    end
    assert_response 302
    assert_redirected_to 'http://localhost.freshpo.com/support/preview'
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_instance_of(Portal::Page, cached_page)
    assert_equal(cached_page.content, new_content)
    ticket.delete
  end

  def test_redirect_after_update_preview_other_than_ticket_view
    portal_page_label = :topic_view
    page_type = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[portal_page_label]
    page = @account.main_portal.template.pages.new(page_type: page_type)
    new_content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub('h2', 'h4')
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}", portal_page: { page_type: page_type, content: new_content }, preview_button: 'Preview'
    end
    assert_response 302
    assert_redirected_to 'http://localhost.freshpo.com/support/preview'
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_instance_of(Portal::Page, cached_page)
    assert_equal(cached_page.content, new_content)
  end

  def test_soft_reset_portal_page
    page_type = @page_type_array.sample
    portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[page_type]
    page = @account.main_portal.template.pages.new(page_type: page_type)
    new_content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub('h2', 'h4')
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}", portal_page: { page_type: page_type, content: new_content }
    end
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_instance_of(Portal::Page, cached_page)
    assert_equal cached_page.content, new_content

    new_content_1 = (new_content + Faker::Lorem.characters(10))
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}", portal_page: { page_type: page_type, content: new_content_1 }
    end
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_instance_of(Portal::Page, cached_page)
    assert_equal cached_page.content, new_content_1

    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/pages/#{page_type}/soft_reset?page_id=#{page_type}&page_type=#{page_type}"
    end
    cached_page = @account.main_portal.template.page_from_cache(portal_page_label)
    assert_nil cached_page
    assert_equal session['flash'][:notice], 'Page reseted successfully.'
    assert_redirected_to '/admin/portal/1/template#layout'
  end

  private

    def old_ui?
      true
    end
end

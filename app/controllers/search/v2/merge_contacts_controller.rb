# Agent side contact merge search
#
class Search::V2::MergeContactsController < ApplicationController

  include Search::V2::AbstractController
  include ApplicationHelper

  attr_accessor :search_results

  def index
    @klasses        = ['User']
    @search_context = :contact_merge

    search(esv2_contact_merge_models) do |results|
      self.search_results[:results] = reconstruct_result_set(results)
    end
  end

  private

    def reconstruct_result_set(items)
      items.map do |i| 
        {
          :id => i.id, 
          :name => h(i.name), 
          :email => i.email, 
          :title => i.job_title, 
          :company => i.company_name,
          :user_emails => i.emails.join(","),
          :twitter => i.twitter_id.present?,
          :facebook => i.fb_profile_id.present?,
          :phone => i.phone.present?, 
          :searchKey => i.emails.join(",")+i.name, 
          :avatar =>  i.avatar ? i.avatar.expiring_url("thumb",7.days.to_i) : is_user_social(i, "thumb")
        }
      end
    end

    def construct_es_params
      super.tap do |es_params|
        es_params[:source_id] = @source_user.id
      end.merge(ES_V2_BOOST_VALUES[@search_context] || {})
    end

    def handle_rendering
      render :json => self.search_results.to_json
    end

    def initialize_search_parameters
      super
      self.search_results = { results: [] }
      load_source_user
    end

    def load_source_user
      @source_user = current_account.contacts.find_by_id(params[:parent_user])
      unprocessable_entity if @source_user.nil?
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_contact_merge_models
      @@esv2_contact_merge_models ||= {
        'user' => { model: 'User', associations: [{ :account => :features }, :company, :user_emails] }
      }
    end
end

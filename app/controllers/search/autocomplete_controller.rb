class Search::AutocompleteController < ApplicationController

  USER_ASSOCIATIONS = { User => { :include => [{ :account => :features }] }}

  def agents
    begin
      search_results = search_users(true)
      agents = { :results => [] }
      search_results.results.each do |document|
        agents[:results].push(*[{
          :id => document.email, 
          :value => document.name, 
          :user_id => document.id }
        ])
      end
    rescue
      agents = agent_sql
    ensure
      respond_with_kbase agents
    end
  end

	def requesters
    begin
      search_results = search_users
      requesters = { :results => [] }
      search_results.results.each do |document|
       requesters[:results].push(*document.search_data)
      end
    rescue
      requesters = { :results => results.map{|x| x.search_data}.flatten} 
    ensure
      respond_with_kbase requesters
    end
	end

	def companies
    begin 
      search_results = search_companies
      companies = { :results => [] }
      search_results.results.each do |document|
        companies[:results].push(*[{
          :id => document.id, 
          :value => document.name
        }])
      end
    rescue
	    companies = {
        :results => current_account.companies.custom_search(params[:q]).map do |company|
          {:id => company.id, :value => company.name}
        end
      } 
    end
    respond_to do |format|
      format.json { render :json => companies.to_json }
    end
	end

  def tags
    begin
      search_results = search_tags
      tags = { :results => [] }
      search_results.results.each do |document|
        tags[:results].push(*[{
            :value => document.name
          }])
      end
    rescue
      tags = { :results => tag_results.map { |tag| { :value => tag.name } } }
    end
    respond_to do |format|
      format.json { render :json => tags.to_json }
    end
  end

  private

    def respond_with_kbase(users)
      if(!params[:sla])
        users = ensure_kbase users
      end
      respond_to do |format|
        format.json { render :json => users.to_json }
      end
    end

    def search_companies
      search_name_string = 'name:'+params[:q]+'*'
      options = { :load => true, :size => 1000 }
      s = Tire.search Search::EsIndexDefinition.searchable_aliases([Customer], current_account.id),options do |s|
        s.query do |q|
          q.boolean do |b|
            b.should   { string search_name_string  }
          end
        end
      end
      return s  
    end
    
    def search_users(agent=false)
      options = { :load => USER_ASSOCIATIONS, :size => 100 }
      items = Tire.search Search::EsIndexDefinition.searchable_aliases([User], current_account.id),options do |tire_search|
         tire_search.query do |q|
           q.filtered do |f|
             f.query { |q| q.string SearchUtil.es_filter_key(params[:q]), :fields => [ 'email', 'name', 'phone' ], :analyzer => "include_stop" }
             f.filter :term, { :helpdesk_agent => agent } if agent
             f.filter :term, { :account_id => current_account.id }
             f.filter :term, { :deleted => false }
           end
         end
         tire_search.sort { by :name, 'asc' }
      end
    end

    def search_tags
      search_name_string = 'name:'+params[:q]+'*'
      options = { :load => true, :size => 25 }
      items = Tire.search Search::EsIndexDefinition.searchable_aliases([Helpdesk::Tag], current_account.id),options do |tire_search|
        tire_search.query do |q|
          q.boolean do |b|
            b.should   { string search_name_string  }
          end
        end
        tire_search.sort { by :tag_uses_count, 'desc' }
      end
    end

    def ensure_kbase(requesters)
      requesters[:results].push({ 
                      :id => current_account.kbase_email, 
                      :value => "",
                      :details => current_account.kbase_email
                    }) if params[:q] =~ /(kb[ase]?.*)/
      return requesters

    end

    def agent_sql
      if current_account.features?(:multiple_user_emails)
        items = current_account.users.technicians.find(
        :all, 
        :select => ["users.id as `id` , users.name as `name`, user_emails.email as `email_found`"],
        :joins => ["INNER JOIN user_emails ON user_emails.user_id = users.id AND user_emails.account_id = users.account_id"],
        :conditions => ["(users.name like ? or user_emails.email like ?) and users.deleted = 0", "%#{params[:q]}%", "%#{params[:q]}%"], 
        :limit => 1000)
        result = {:results => items.map {|i| {:id => i.email_found, :value => i.name, :user_id => i.id }}}
      else
        items = current_account.users.technicians.find(
        :all, 
        :conditions => ["email is not null and name like ? or email like ?", "%#{params[:q]}%", "%#{params[:q]}%"], 
        :limit => 1000)
        result = {:results => items.map {|i| {:id => i.email, :value => i.name, :user_id => i.id }}}
      end
      return result
    end

  	def results
      @results ||= begin 
        return [] if params[:q].blank? 
        current_account.users.find(:all, :conditions => send("requester_conditions"), :limit => 100 )
      end
  	end  

    def requester_conditions
      ["name like ? or email like ? or phone like ?","%#{params[:q]}%","%#{params[:q]}%","%#{params[:q]}%"]
    end	

    def tag_results
      @results ||= begin 
        current_account.tags.find(:all, :order => "tag_uses_count desc", :limit => 25)
      end
    end

end
class Search::AutocompleteController < ApplicationController

  USER_ASSOCIATIONS = { User => { :include => [{ :account => :features }, :user_emails] }}

  skip_before_filter :check_privilege, :only => [:company_users]

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

  def company_users
    begin
      requesters = { :results => [] }
      @customer_id = params[:customer_id].to_i
      if params[:customer_id].present? and current_user.company_ids.include?(@customer_id)
        search_results = search_users
        search_results.results.each do |document|
         requesters[:results].push(*document.search_data)
        end
      end
    rescue
      requesters = { :results => results.map{|x| x.search_data}.flatten} 
    ensure
      respond_with_kbase requesters
    end
  end

  def tags
    begin
      search_results = search_tags
      tags = { :results => [] }
      search_results.results.each do |document|
        tags[:results].push(*[{
            :value => document.name,
            :id => document.id
          }])
      end
    rescue
      tags = { :results => tag_results.map { |tag| { :value => tag.name, :id => tag.id } } }
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
      Search::EsIndexDefinition.es_cluster(current_account.id)
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
      Search::EsIndexDefinition.es_cluster(current_account.id)
      items = Tire.search Search::EsIndexDefinition.searchable_aliases([User], current_account.id),options do |tire_search|
         tire_search.query do |q|
           q.filtered do |f|
             f.query { |q| q.match [ 'email', 'name', 'phone', 'mobile', 'user_emails.email' ], SearchUtil.es_filter_key(params[:q], false), :type => :phrase_prefix }
             f.filter :term, { :helpdesk_agent => agent } if agent
             f.filter :term, { :account_id => current_account.id }
             f.filter :term, { :deleted => false }
             f.filter :term, { :customer_id => customer_id } if @customer_id
           end
         end
         tire_search.sort { by :name, 'asc' }
      end
    end

    def search_tags
      search_name_string = 'name:'+params[:q]+'*'
      options = { :load => true, :size => 25 }
      Search::EsIndexDefinition.es_cluster(current_account.id)
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
                    }) if current_account.kbase_email.start_with?(params[:q])
      return requesters

    end

    def agent_sql
      items = current_account.users.technicians.find(
      :all, 
      :select => ["users.id as `id` , users.name as `name`, user_emails.email as `email_found`"],
      :joins => ["INNER JOIN user_emails ON user_emails.user_id = users.id AND user_emails.account_id = users.account_id"],
      :conditions => ["(users.name like ? or user_emails.email like ?) and users.deleted = 0", "%#{params[:q]}%", "%#{params[:q]}%"], 
      :limit => 1000)
      {:results => items.map {|i| {:id => i.email_found, :value => i.name, :user_id => i.id }}}
    end

  	def results
      @results ||= begin 
        return [] if params[:q].blank? 
        current_account.users.find(:all, :conditions => send("requester_conditions"), :limit => 100 )
      end
  	end  

    def requester_conditions
      if @customer_id
        ["(name like ? or email like ? or phone like ?) and customer_id = ?","%#{params[:q]}%","%#{params[:q]}%","%#{params[:q]}%", params[:customer_id]]
      else
        ["name like ? or email like ? or phone like ?","%#{params[:q]}%","%#{params[:q]}%","%#{params[:q]}%"]
      end
    end	

    def tag_results
      @results ||= begin 
        current_account.tags.find(:all, :order => "tag_uses_count desc", :limit => 25)
      end
    end

end
class Search::AutocompleteController < ApplicationController

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
        :results => current_account.customers.custom_search(params[:q]).map do |company|
          {:id => company.id, :value => company.name}
        end
      } 
    end
    respond_to do |format|
      format.json { render :json => companies.to_json }
    end
	end

  private

    def respond_with_kbase(users)
      users = ensure_kbase users
      respond_to do |format|
        format.json { render :json => users.to_json }
      end
    end

    def search_companies
      search_name_string = 'name:'+params[:q]+'*'
      options = { :load => true }
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
      search_name_string = 'name:'+params[:q]+'*'
      search_email_string = 'email:'+params[:q]+'*'
      search_agent_string = 'helpdesk_agent:0'
      options = { :load => true }
      s = Tire.search Search::EsIndexDefinition.searchable_aliases([User], current_account.id),options do |s|
        s.query do |q|
          q.boolean do |b|
            b.should   { string search_email_string }
            b.should   { string search_name_string  }
            b.must_not { string search_agent_string } if agent
          end
        end
      end
      return s
    end

    def ensure_kbase(requesters)
      requesters[:results].push({ 
                      :id => current_account.kbase_email, 
                      :value => ""
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

end
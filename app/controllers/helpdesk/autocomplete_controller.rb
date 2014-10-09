class Helpdesk::AutocompleteController < ApplicationController
	
	def requester
		requesters = { :results => results.map{|x| x.search_data}.flatten} 
		requesters[:results].push({ 
                  :id => current_account.kbase_email, 
                  :value => ""
                }) if params[:q] =~ /(kb[ase]?.*)/

		respond_to do |format|
			format.json { render :json => requesters.to_json }
		end
	end

  def company
    companies = {:results => results.map { |i| {:id => i.id, :value => i.name}}} 

    respond_to do |format|
      format.json { render :json => companies.to_json }
    end
  end

  protected

  	def results
      @results ||= begin 
        return [] if params[:q].blank? 
        if @current_action == "requester"
          scoper.matching_users_from(params[:q])
        else
          scoper.find(:all, :conditions => send("#{current_action}_conditions"), :limit => 100 )
        end
      end
  	end
  	
  	def scoper
  		send("#{current_action}_scope")
  	end

    def current_action
      @current_action ||= begin
        allowed_actions = ['requester','company']
        allowed_actions.include?(params[:action]) ? params[:action] : allowed_actions.first  
      end
    end

  	def requester_scope
  		current_account.users
  	end

  	def company_scope
  		current_account.companies
  	end

  	def requester_conditions
  		["name like ? or email like ? or phone like ?","%#{params[:q]}%","%#{params[:q]}%","%#{params[:q]}%"]
  	end

  	def company_conditions
  		["name like ?", "%#{params[:q]}%"]
  	end

end
var HarvestWidget = Class.create();
HarvestWidget.prototype= {
	initialize:function(a){
		this.id = a.id;
		this.harvest_domain=a.domain;
		this.ssl_enabled=a.ssl_enabled;
		this.ticket_id=a.ticket_id;
		this.display_id=a.display_id;
		if(this.display_id==undefined){
			this.display_id=this.ticket_id;
		}
		if(this.harvest_domain&&this.ticket_id){
			this.harvest_resource=new Freshdesk.Widget(
				{
					anchor:"harvest_widget",
					domain:this.harvest_domain,
					ssl_enabled:this.ssl_enabled||"false",
					login_content:this.login.bind(this),
					application_content:this.application.bind(this),
					application_resources:[{
						resource:"daily",
						on_success:this.projectsSelector.bind(this)}]
				});
		}else{
			this.containingElement().down("div#content").update("Only available when viewing tickets");
		}
	},
	
	login:function(){
		return'<form onsubmit="ObjectFactory.get('+this.id+').harvest_resource.login(this);return false;" class="form"><label>Username</label><input type="text" id="username"/><label>Password</label><input type="password" id="password"/><br/><input type="submit" value="Login" id="submit"></form>';
	},
	
	application:function(){
		return"<form onsubmit=\"if (parseFloat(this['request[hours]'].value)==NaN) {alert('Please enter a valid value for hours');return false;}; this['request[notes]'].value +=' (ticket #"+this.display_id+")'; ObjectFactory.get("+this.id+').harvest_resource.submit_data(this); return false;" class="form"><label>Select project</label><select name="request[project_id]" id="harvest-form-projects" onchange="ObjectFactory.get('+this.id+').tasksSelector(this.options[this.selectedIndex].value)"></select><label>Select task</label><select name="request[task_id]" id="harvest-form-tasks"></select><label>Notes</label><input type="text" name="request[notes]"/><label><b>Hours</b></label><input type="text" name="request[hours]" size="5" maxlength="5"/><br/><input type="hidden" name="request[spent_at]" value="'+Date("dd/mm/yyyy")+'"><input type="hidden" name="entity_name" value="request"><input type="hidden" name="resource" value="daily/add"><input type="hidden" name="content_type" value="application/json"><input type="hidden" name="event_reference" value="Harvest time tracking"><input type="hidden" name="event_log" value="Project,Task,Notes,Hours,location,ID"><input type="submit" value="Submit" id="submit"><span class="link" style="font-weight:normal;margin-left:20px;" onclick="ObjectFactory.get('+this.id+').harvest_resource.logout()">(logout)</span></form>';
	},
	
	projectsSelector:function(a){
		var e="";
		var c=$("harvest-form-projects");
		var d;
		c.update();
		projects=$A(a.projects);
		if(projects.length==0){
			return;
		}
		projects.sortBy(function(f){
			return f.client+f.name;
		}).each(function(g){
			if(e!=g.client){	
				if(e!=""){
					c.appendChild(d);
				}
				d=new Element("optgroup");
				d.setAttribute("label",g.client);
				e=g.client;
			}
			var f=new Element("option");
			f.value=g.id;
			f.update(g.name);
			d.appendChild(f);
		});
		c.appendChild(d);
		c.selectedIndex=0;
		if(projects.length>0){
			this.tasksSelector(projects[0].id);
		}
	},
	
	tasksSelector:function(c){
		var a=false;
		var d="";
		$("harvest-form-tasks").update();
		projects.each(function(e){
			if(e.id==c){
				$A(e.tasks).sortBy(function(f){
					return !f.billable+f.name;
				}).each(function(f){
					var g=new Element("option");
					g.value=f.id;
					g.update(f.name);
					currentTask=f.billable?"Billable":"Non-billable";
					if(d!=currentTask){
						if(d!=""){
							$("harvest-form-tasks").insert(optGroup);
						}
						optGroup=new Element("optgroup");
						optGroup.setAttribute("label",currentTask);
						d=currentTask;
					}
					optGroup.appendChild(g);
				});
				$("harvest-form-tasks").insert(optGroup);
			}
		});
	}
}


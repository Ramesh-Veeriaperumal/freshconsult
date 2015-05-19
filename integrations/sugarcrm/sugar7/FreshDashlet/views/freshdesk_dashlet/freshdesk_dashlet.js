({

	plugins: ['Dashlet'],

	initDashlet: function() {
		if(this.meta.config) {
			var limit = this.settings.get("limit") || "5";
			this.settings.set("limit", limit);
		}
	},

	personalCredentials: function (event, params) {
		var module = 'freshdesk';
		var return_action = '';
		if (!_.isUndefined(app.controller.context.get("model").action)) {
    			return_action = app.controller.context.get("model").action;
    		}
        	var route = app.bwc.buildRoute(module, null, 'settings', {
			return_module: app.controller.context.get("model").module,
			return_id: app.controller.context.get("model").id,
			return_action: return_action,
		});
		app.router.navigate(route, {
		    trigger: true
		});
	},

	loadData: function (options) {
		var name, limit;

		if(_.isUndefined(this.model)){
		return;
		}
		var email = this.model.get("email");
		var self = this;
		var url = app.api.buildURL('freshdeskdashlet', null, null, {
			"record": app.controller.context.get("model").id,
			"module": app.controller.context.get("model").module
		});
		var ticket_field_url = app.api.buildURL('ticketfields', null, null, {
			"record": app.controller.context.get("model").id,
			"module": app.controller.context.get("model").module
		});
		var name = this.model.get("account_name") || this.model.get('name') || this.model.get('full_name'),
									limit = parseInt(this.settings.get('limit') || 5, 10);

		if (_.isEmpty(name)) {
			return;
		}

		app.api.call("GET", url, null, {
			success: function (data) {
				if (self.disposed) {
					return;
				}

				try {
					var description = data['ticket_json'][0]['description'];
										_.extend(self, data);
					self.render();
				} catch(ex) {
					console.log("There is no ticket or the got JSON is null");
					console.log(ex);
					_.extend(self, {showConfig: true, moduleName:app.controller.context.get("model").module  , recId: app.controller.context.get("model").id });
					self.render();
				}
			},
			error: function (data) {
				console.log("Failure while calling the FreshdeskDashletAPI");
				console.log(data);
				_.extend(self, {showConfig: true, moduleName:app.controller.context.get("model").module  , recId: app.controller.context.get("model").id });
				self.render();
			},
			complete: options ? options.complete : null
		});
	}

})

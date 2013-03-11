
/* Google Calendar class defnition */

var GoogleCalendar = Class.create(), gcal;
var systemTimezone = (new Date()).getTimezoneOffset();

GoogleCalendar.prototype = {
	EVENT_REQUEST_BODY: 	new Template('{ \
										"summary": "#{summary}", \
										"description": "#{description}", \
										 "start": { \
										  "dateTime": "#{start_datetime_string}" \
										 }, \
										 "end": { \
										  "dateTime": "#{end_datetime_string}" \
										 } \
											}'),

	EVENT_TEMPLATE: new Template('<div class="row-fluid event  #{custom_class}" id="event_#{id}"> \
										<div class="">\
											<span class="time-container">#{formatted_time}</span>\
											<span class="pull-right hide edit-delete-event">\
												<a href="#edit_event" evid="#{id}" target="_blank">Edit</a> \
								            	<span>-</span> \
								            	<a href="#delete_event" evid="#{id}">Delete</a> \
											</span>\
										</div> \
										<div class="event-summary">\
											<b><a href="#{event_link}" target="_blank">#{event_summary}</a></b> \
										</div> \
										<div class="event-description">#{event_description}</div> \
									</div>'),

	DATE_SECTION_TEMPLATE: new Template('<div class="row-fluid muted date-section #{custom_class}">\
											<div class="lead span2"> #{((date<10)?"0":"")}#{date}</div>\
											<div class="span3 day-month-year">#{day}<br>#{month} #{year}</div>\
											<div class="span7 #{((date_closeness.length)?"":"hide")}"><span class="date-closeness pull-right">#{date_closeness}</span></div>\
										</div>'),


	ADD_EDIT_EVENT_TEMPLATE : 	 new Template(' \
	<div id="google_calendar_add_event_modal" class="hide"> \
		<div id="gcal-validation-errors" class="alert alert-error hide"><ul></ul></div> \
		<div class="gcal-custom-errors alert alert-error hide"><span>Could not create event. Please try again after sometime.</span></div> \
		<form action="#" class="googleCalendar" id="gcal-add-event-form"> \
			<div class="gcal-form-contents"> \
			    <div class="row-fluid"> \
			        <div class="span2"> \
			            <span class="field-label"> \
			                Event Title \
			            </span> \
			        </div> \
			        <div class="span10"> \
			            <input class="input-block-level span11 required" type="text" id="gcal-event-summary"> \
			        </div> \
			    </div> \
			    <div class="row-fluid"> \
			        <div class="span2"> \
			            <span class="field-label"> \
			                When \
			            </span> \
			        </div> \
			        <div class="span10"> \
			            <input class="span4 required" id="gcal-start-date-field" type="text" readonly autocomplete="off"> \
		    	    	<input id="gcal-start-date-alt-field" type="hidden"> \
		    	    	<input id="gcal-end-date-alt-field" type="hidden"> \
		                <input class="span2 g-time required time_12" type="text" id="gcal-start-time-field" placeholder="hh:mm" value="" autocomplete="off"> \
			            <span class="hyphen-container">-</span> \
		                <input class="span2 g-time required time_12" type="text" value="" id="gcal-end-time-field" placeholder="hh:mm" autocomplete="off"> \
			            <span id="gcal-event-duration"></span> \
			        </div> \
			    </div> \
			    <div class="row-fluid"> \
			        <div class="span2"> \
			            <span class="field-label"> \
			                Description \
			            </span> \
			        </div> \
			        <div class="span10"> \
			        	<textarea id="google_calendar_event_description" class="span11" rows="3"></textarea> \
			        </div> \
		        </div> \
		        <div class="row-fluid"> \
			        <div class="span2"> \
			            <span class="field-label"> \
			                Calendar \
			            </span> \
			        </div> \
			        <div class="span10"> \
			        	<select id="gcal-calendar-list" class="required">#{calendarOptions}</select> \
			        </div> \
		        </div> \
		        <div class="row-fluid"> \
		        	<input type="submit" id="gcal-submit-event-button" class="btn btn-primary pull-right"> \
		        	<input type="button" id="gcal-add-update-modal-cancel-button" class="pull-right btn" value="Cancel" > \
		        </div> \
			</div> \
		</form> \
	</div>'), 

	CONFIG_TEXT: new Template('<span class="error">Please authorize Freshdesk to access your calendar information.<br><a href="#{oauth_url}" id="gcal-authorize-link">Authorize Now</a>.</span>'),

	NO_EVENT_FOR_TICKET_MSG: new Template('<span class="error">No event linked with this ticket.</span>'),
	
	NO_UPCOMING_EVENTS: 	new Template('<div class="error">No upcoming events.</div>'),

	NO_FUTURE_EVENT_FOR_TICKET_MSG: new Template('<div class="error">No upcoming events for this ticket.</div>'),
	
	OTHER_TICKET_EVENTS_DIV : new Template('	<div id="gcal-other-tickets-events-pane"> \
													<div id="gcal-other-events-link-container"><span class="arrow-right" id="gcal-other-tickets-arrow"></span><span class="label notice">#{n}</span><a href="#other_events" id="gcal-other-events-link">Other event<span>#{pluralization}</span> today</a></div> \
														<div id="gcal-other-tickets-events-container" class="#{container_class}"> '),

	OPTION_TAG : 			new Template('<option value="#{value}" #{selected_attrib}>#{html}</option>'),
	EVENTS_LIST_REQBODY : 		new Template('calendarId=#{calendarId}&alwaysIncludeEmail=#{alwaysIncludeEmail}&orderBy=#{orderBy}&singleEvents=#{singleEvents}&q=#{q}&showDeleted=#{showDeleted}&timeMin=#{timeMin}&timeMax=#{timeMax}&timeZone=#{timeZone}'),

	 GCAL_CONFIRM_MODAL: 	new Template('<div id="gcal-confirm-modal" class="hide"> \
														<div class="confirm-modal-content">#{content}</div> \
													</div>'),

	calEvents : [], // List of all events (incuding that of other tickets)
	otherTicketEvents: [], // List of just the events of other tickets

	initialize: function(google_calendar_options){
		gcal = this; // Set this way because gcal is used before the constructore returns.
		jQuery("#google_calendar_events_container").addClass("loading-fb");
		
		google_calendar_options.app_name = "Google Calendar";
		google_calendar_options.auth_type = "OAuth";
		google_calendar_options.ssl_enabled = true,
		google_calendar_options.integratable_type = "issue-tracking";
		google_calendar_options.init_requests = [null, {
			rest_url: 'calendar/v3/users/me/calendarList',
			accept_type: "application/json",
			on_success: function (resData) {
							gcal.nLoadingEvents--;
							gcal.saveCalendarList(resData);
							gcal.loadOtherTicketEvents();
						},
			after_failure: function(){
				gcal.nLoadingEvents--;
				gcal.populateEvents();
			}
		}];
		this.google_calendar_options = google_calendar_options;

		this.nLoadingEvents = google_calendar_options.events_list.length; // No. of this ticket events.
		this.event_id_to_calendar_id = {};
		this.event_id_to_integrated_resource_id = {};
		this.calendarsById = {};

		if(google_calendar_options.oauth_token==''){
			jQuery('#google_calendar_widget').css('height', '75px').find('div.title').append(
				this.CONFIG_TEXT.evaluate({oauth_url: google_calendar_options.oauth_url})  );
			jQuery("#google_calendar_events_container").removeClass("loading-fb");
			jQuery("#add_event_link").hide();
		} else {
			gcal.nLoadingEvents++;
			this.freshdeskWidget = new Freshdesk.Widget(google_calendar_options);
			this.loadThisTicketEvents();
		}
	},

	loadThisTicketEvents: function(){
		fw = this.freshdeskWidget;
		for(i=0; i<this.google_calendar_options.events_list.length; i++)
		{
			evt = this.google_calendar_options.events_list[i];
			s = evt.remote_integratable_id.split(":");
			calendarId = s[0]; eventId = s[1];
			this.event_id_to_integrated_resource_id[eventId] = evt.integrated_resource_id;
			fw.request({
				rest_url: 'calendar/v3/calendars/' + calendarId + '/events/' + eventId,
				accept_type: "application/json",
				method: "get",
				on_success: function(resData){ 
					console.log('This ticket event ' + resData.responseJSON.id + ' loaded');
					this.nLoadingEvents--;
					this.showEvent(resData);}.bind(this),
				after_failure: function(evt){
					gcal.nLoadingEvents--;
					gcal.populateEvents();
				}
			});
		}
		if(!i) this.populateEvents();
	},

	loadOtherTicketEvents: function(){
		gcal.allCalendars.each(function(cal){
			gcal.nLoadingEvents++;
			gcal.freshdeskWidget.request({
				rest_url: 'calendar/v3/calendars/' + cal.id + '/events?' + 
						gcal.EVENTS_LIST_REQBODY.evaluate({
							calendarId: cal.id,
							alwaysIncludeEmail: true,
							orderBy: "startTime",
							singleEvents: true,
							q: SEARCH_KEYWORD,
							showDeleted: false,
							timeMin: getMinTimeToday().toISO8601(),
							timeMax: getMaxTimeToday().toISO8601(),
							timeZone: systemTimezone
						}),
				accept_type: "application/json",
				method: "get",
				on_success: function(resData){ 
					gcal.nLoadingEvents--;
					gcal.otherTicketEvents = gcal.otherTicketEvents || [];
					resJSON = resData.responseJSON.items;
					if(resJSON){
						resJSON.each(function(evt){
							evt.isOfOtherTicket=true; 
							if(evt.description)  evt.description = evt.description.split(SEARCH_KEYWORD)[0];
							evt.description = evt.description.substring(0, evt.description.length-1);
							if( !gcal.isThisTicketEvent(evt.id) )
								gcal.otherTicketEvents.push(evt);
						});
					}
					gcal.populateEvents();
				},
				after_failure: function(resData){
					gcal.nLoadingEvents--;
					gcal.populateEvents();
				}
			});
		});		
	},

	showEvent: function(resData){	
		if(animatingOldEvents || animatingOtherTicketEvents){
			setTimeout("gcal.showEvent("+JSON.stringify(resData)+")", ANIMATION_TIME+10);
			return; 
		}
		eventRes = resData.responseJSON || resData;
		if(eventRes.description) {
			eventRes.description = eventRes.description.split(SEARCH_KEYWORD)[0];
			eventRes.description = eventRes.description.substring(0, eventRes.description.length-1); 
		}
		this.calEvents.push(eventRes);

		this.populateEvents();
		this.updateCalId(eventRes);
	},

	submitForm: function(){
		btn_val = jQuery('#gcal-submit-event-button').val();
		if(btn_val=="Adding..." || btn_val=="Updating...") return false;
		if(this.updatingEvent_id) this.editEvent(this.updatingEvent_id);
		else this.addNewEvent();
		return false;
	},

	addNewEvent: function(){
	
		startDateTime = gcal.getStartDateTime();
		endDateTime = gcal.getEndDateTime();
		cFrom = startDateTime.toISO8601();
		cTo = endDateTime.toISO8601();
		
		reqBody = gcal.EVENT_REQUEST_BODY.evaluate({summary: escapeJSON(jQuery("#gcal-event-summary").val()),
			start_datetime_string: cFrom, end_datetime_string: cTo,
			description: escapeJSON(jQuery("#google_calendar_event_description").val()
						 + '\n' + SEARCH_KEYWORD + ': ' + jQuery(".subject").html() + '\n' + document.location.href)
		});

		selected_calendar_id = jQuery('#gcal-calendar-list option:selected').val();

		// alert("Event added.."); 
		(gcal.freshdeskWidget.request.bind(gcal.freshdeskWidget))({
			body: reqBody,
			on_success: function(evResData){
				// alert("Added in Google Calendar");
				addedEvent = evResData.responseJSON;
				gcal.freshdeskWidget.application_id = google_calendar_options.application_id;
				gcal.freshdeskWidget.local_integratable_id = google_calendar_options.ticket_id;
				gcal.freshdeskWidget.remote_integratable_id = selected_calendar_id + ":" + addedEvent.id;
				gcal.freshdeskWidget.create_integrated_resource(function(resData){
					// Store integrated resource data
						intResource = resData.responseJSON.integrated_resource;
						gcal.event_id_to_integrated_resource_id[addedEvent.id] = intResource.id;
					// Set the lastly used calendar (to set it as default while reoping add event dialog)
						gcal.recently_used_calendar_id = selected_calendar_id;
					// Add event id => calId map for easy retrieval
						gcal.event_id_to_calendar_id[addedEvent.id] = selected_calendar_id;
					// Close dialog, display newly added event & highlight it.
						jQuery("#google_calendar_add_event_modal form input, #google_calendar_add_event_modal form select, #google_calendar_add_event_modal form textarea").removeAttr("disabled")
						jQuery("#gcal-submit-event-button").val("Add Event");
						jQuery("#google_calendar_add_event_modal").prev().find(".ui-dialog-titlebar-close").show();
						gcal.preventDialogClose = false;
						jQuery("#google_calendar_add_event_modal .gcal-custom-errors").hide();
						jQuery("#google_calendar_add_event_modal").dialog("close");
						gcal.showEvent(addedEvent);
						jQuery("#event_"+addedEvent.id).effect("highlight", {color: "yellow", easing: "easeOutQuart"}, 1500);
					// Reset "add event" form, but just remember the lastly used calendar.
						gcal.updateCalendarOptions();
						jQuery("#gcal-add-event-form")[0].reset();
						gcal.startTimeSelected = false;
						gcal.duration = DEFAULT_EVENT_DURATION;


				});
			},
			content_type: "application/json",
			method: "post", 
			rest_url: "calendar/v3/calendars/" + selected_calendar_id + "/events",
			after_failure: function (evResData) {
				jQuery("#gcal-submit-event-button").val("Add Event");
				jQuery("#google_calendar_add_event_modal form input, #google_calendar_add_event_modal form select, #google_calendar_add_event_modal form textarea").removeAttr("disabled");
				jQuery("#google_calendar_add_event_modal").prev().find(".ui-dialog-titlebar-close").show();
				gcal.preventDialogClose = false;
				jQuery("#google_calendar_add_event_modal .gcal-custom-errors").show();
			}
		});
		jQuery("#gcal-submit-event-button").val("Adding...")
		// jQuery("#google_calendar_add_event_modal form input, #google_calendar_add_event_modal form select, #google_calendar_add_event_modal form textarea").attr("disabled", "disabled");
		jQuery("#google_calendar_add_event_modal").prev().find(".ui-dialog-titlebar-close").hide();
		gcal.preventDialogClose = true;
		jQuery("#google_calendar_add_event_modal .gcal-custom-errors").hide();
		//jQuery("form[onsubmit] > div input, form[onsubmit] > div select")
		return false;
	},

	editEvent: function(eventId){
	
		orgEvent = gcal.getEventById(eventId);

		startDateTime = gcal.getStartDateTime();
		endDateTime = gcal.getEndDateTime();
		cFrom = startDateTime.toISO8601();
		cTo = endDateTime.toISO8601();
		
		reqBody = gcal.EVENT_REQUEST_BODY.evaluate({summary: escapeJSON(jQuery("#gcal-event-summary").val()),
			start_datetime_string: cFrom, end_datetime_string: cTo,
			description: escapeJSON( jQuery("#google_calendar_event_description").val()
									+ '\n' + SEARCH_KEYWORD + ': ' + jQuery(".subject").html() + '\n' + document.location.href)
		});

		selected_calendar_id = jQuery('#gcal-calendar-list option:selected').val();

		// alert("Event Editd.."); 
		calendarId=gcal.getCalId(eventId);
		fw = gcal.freshdeskWidget;
		fw.request.bind(fw)({
			body: reqBody,
			rest_url: "calendar/v3/calendars/" + calendarId + "/events/" + eventId,
			content_type: "application/json",
			method: "patch", 
			on_success: function(evResData){
				// alert("Added in Google Calendar");
				if(calendarId != selected_calendar_id)
					fw.request.bind(fw)({
						content_type: "application/x-www-form-urlencoded",
						accept_type: "application/json",
						method: "post",
						rest_url: "calendar/v3/calendars/" + calendarId + "/events/" + eventId + "/move",
						body: "calendarId="+calendarId+'&destination='+selected_calendar_id+'&eventId='+eventId,
						on_success: function(res){console.log("Event Moved to new calendar successfuly.");
									gcal.updateCalId(res.responseJSON);
						}
					});
				updatedEvent = evResData.responseJSON;
				jQuery("#gcal-submit-event-button").val("Update");
				jQuery("#google_calendar_add_event_modal").prev().find(".ui-dialog-titlebar-close").show();
				gcal.preventDialogClose = false;
				jQuery("#google_calendar_add_event_modal").dialog("close");
				gcal.calEvents.splice(gcal.getEventIndexById(eventId), 1);
				gcal.showEvent(updatedEvent);
				jQuery("#event_"+eventId).effect("highlight", {color: "yellow", easing: "easeOutQuart"}, 1500);
				this.updatingEvent_id = null;
				// gcal.renderAddForm();
			},
			after_failure: function (evt) {
				// jQuery("#google_calendar_add_event_modal").dialog("close");
				jQuery("#gcal-submit-event-button").val("Update");
				jQuery("#google_calendar_add_event_modal").prev().find(".ui-dialog-titlebar-close").show();
				gcal.preventDialogClose = false;
				jQuery("#google_calendar_add_event_modal .gcal-custom-errors").show();
			}
		});
		jQuery("#gcal-submit-event-button").val("Updating...");
		jQuery("#google_calendar_add_event_modal").prev().find(".ui-dialog-titlebar-close").hide();
		gcal.preventDialogClose = true;
		jQuery("#google_calendar_add_event_modal .gcal-custom-errors").hide();

		return false;
	},

	updateCalId: function(eventRes){
		// Find out which calendar has event 'eventRes' and update integrated_resources if required.
		evl = google_calendar_options.events_list;
		fw=gcal.freshdeskWidget;
		eventId = eventRes.id; 
		oldCalId = this.getCalId(eventId); newCalId = (eventRes.organizer.email || eventRes.creator.email);
		if(newCalId != oldCalId){ // for(i=0; i<evl.length; i++){
			resId = gcal.event_id_to_integrated_resource_id[eventId];
			fw.update_integrated_resource(resId, null, newCalId+':'+eventId);
		}
		this.event_id_to_calendar_id[eventId] = newCalId;
	},

	deleteEvent: function(eventId){
		var reqData;
		jQuery('#event_'+eventId).animate({backgroundColor: '#FFD8D8'}, 1500).unbind();
		calId = gcal.getCalId(eventId);
		fw = gcal.freshdeskWidget;
		fw.request(reqData={
			rest_url: "calendar/v3/calendars/"+calId+"/events/"+eventId,
			method: "delete",
			on_success: function(resData){ gcal.onEventDeletedFromGoogle(eventId)},
			after_failure: function(resData){ 
				// if(resData.status == 401) {fw.refresh_access_token(fw.request.apply(fw, [reqData])); return;}
				gcal.populateEvents(); alert('Could not delete the event.');},
			custom_callbacks: {
				on204: function(resData){gcal.onEventDeletedFromGoogle(eventId)},
				on410: function(resData){gcal.onEventDeletedFromGoogle(eventId)},
				on404: function(resData){gcal.onEventDeletedFromGoogle(eventId)}
			}
		});
	},

	onEventDeletedFromGoogle: function(eventId){
		resId = gcal.event_id_to_integrated_resource_id[eventId];
		if(resId) gcal.freshdeskWidget.delete_integrated_resource(resId);		
		gcal.calEvents.splice(gcal.getEventIndexById(eventId), 1);		
		gcal.populateEvents();
	},

	saveCalendarList: function(resData){
		resJSON = resData.responseJSON;
		this.calendars = [];
		this.allCalendars = resJSON.items;
		resJSON.items.each( function(cal){
			if(cal.accessRole == 'owner' || cal.accessRole == 'writer') gcal.calendars.push(cal);
			gcal.calendarsById[cal.id] = cal;
		});
		this.calendars.sort(function(a, b){
			return a.summary.toUpperCase().localeCompare(b.summary.toUpperCase());
		});

		this.updateCalendarOptions();		
	},

	updateCalendarOptions: function(){
		calendarOptions = "";
		var selected_calendar_id = this.recently_used_calendar_id;
		if(!selected_calendar_id && google_calendar_options.events_list.length)
		{
			remote_integratable_ids = google_calendar_options.events_list[google_calendar_options.events_list.length-1].remote_integratable_id.split(':');
			selected_calendar_id = remote_integratable_ids[0];
		}
		this.calendars.each(function(cal){
			calendarOptions += gcal.OPTION_TAG.evaluate({	value: cal.id,
																	html: cal.summary,
																	selected_attrib: (cal.id == selected_calendar_id) ? 'selected=\"selected\"' : ''
																});		
		});
		this.calendarOptions = calendarOptions; 
		// Save options; reply might be processed before the doc loads (see .ready())
		jQuery('#gcal-calendar-list').html(this.calendarOptions);
	},

	sortCalEvents: function(){

		var calEvents = this.calEvents;
		
		for(i=0; i<calEvents.length; i++){
			if(calEvents[i].isOfOtherTicket){
				calEvents.splice(i, 1);
				i--; // Splice removes an element. so compensate for it!
			}
		}

		var compareDateObjects = function(a, b){
			ta = Date.parseISO8601(a.start.dateTime);
			tb = Date.parseISO8601(b.start.dateTime);
			return ta-tb;
		};

		this.calEvents.sort(compareDateObjects);		
		this.otherTicketEvents.sort(compareDateObjects);
				
		var startIndex = null;
		todayEventsBegan = false;
		
		for(i=0; i<calEvents.length; i++){
			if(isEventToday(calEvents[i]))
				todayEventsBegan = true;
			else if(todayEventsBegan){
				startIndex = i;
				todayEventsBegan = false;
				break;
			}
		}			
		if(todayEventsBegan) startIndex = i;

		
		if(startIndex == null){
			for(i=0; i<calEvents.length; i++){
				isOldEvent = (!isFutureEvent(calEvents[i]) && !isEventToday(calEvents[i]))
				if(!isOldEvent){
					startIndex = i;
					break;
				}
			}			
		}

		if(startIndex == null) startIndex = calEvents.length;

		for(i=0; i<gcal.otherTicketEvents.length; i++){
			calEvents.splice(startIndex+i, 0, gcal.otherTicketEvents[i]);
		}
	},

	populateEvents: function(){

		if(this.nLoadingEvents) return; // Wait for loading to complete.
		
		jQuery("#google_calendar_events_container").removeClass("loading-fb");

		calEvents = this.calEvents;
		this.sortCalEvents();

		var isOldEvent, isOldEventsDivClosed = false, otherTicketEventsDivOpen = false;
		
		var cal_html = '';
		var evNo = 0;
		var evDate = zeroDate();
		jQuery("#gcal-older-events-link-container").hide();
		for(i=0; i<calEvents.length; i++)
			if(!calEvents[i].isOfOtherTicket) 
				break;
		if(calEvents.length == i)
			jQuery("#google_calendar_events_container").html(this.NO_EVENT_FOR_TICKET_MSG.evaluate({}));					
		if(!calEvents.length) return;
		while(evNo < calEvents.length){
			var ev = calEvents[evNo];
			if(!isEventOn(ev, evDate)){
				(evDate = new Date()).setTime(Date.parseISO8601(ev.start.dateTime));
				var evDate_date = evDate.getDate();
				if(otherTicketEventsDivOpen){
					cal_html += "</div></div>";
					otherTicketEventsDivOpen = false;
				}		
				if ( isOldEvent = (!isFutureEvent(ev) && !isEventToday(ev)) )
					jQuery("#gcal-older-events-link-container").show();
				if(evNo == 0) cal_html += "<div id='gcal-old-events'>" ;
				if(!isOldEvent && !isOldEventsDivClosed) {
					cal_html += "</div>";
					isOldEventsDivClosed = true;					
				}
				cal_html += this.DATE_SECTION_TEMPLATE.evaluate({
															date: (evDate_date<10?"0":"") + evDate_date,
															day: DAY[evDate.getDay()],
															month: MONTH[evDate.getMonth()],
															year: evDate.getFullYear(),
															date_closeness: isEventToday(ev) ? "Today" : (isEventTomorrow(ev)?"Tomorrow": (isEventYesterday(ev)?"Yesterday":"")),
															custom_class: '' 
														});
				// if(ev.isOfOtherTicket){
				// 	if(!this.eventExistsTomorrowOrLater()){
				// 		cal_html += this.NO_FUTURE_EVENT_FOR_TICKET_MSG.evaluate({});
				// 		errorShown = true;
				// 	}
				// }

			}
			if(ev.isOfOtherTicket && !otherTicketEventsDivOpen){
				cal_html += this.OTHER_TICKET_EVENTS_DIV.evaluate({n: this.otherTicketEvents.length, pluralization:  this.otherTicketEvents.length>1?'s':'', container_class: otherTicketEventsDisplayed?"":"hide"});
				otherTicketEventsDivOpen = true;
			}

			var description = calEvents[evNo].description;


			// description = "";
			if(description.length > 120) description = description.substring(0, 120) + "...";
			cal_html += this.EVENT_TEMPLATE.evaluate({event_description: description,
												event_summary: calEvents[evNo].summary,
												formatted_time: formatEventTime(calEvents[evNo].start, calEvents[evNo].end),
												custom_class: isFutureEvent(ev)?'':'past-event', 
												id: calEvents[evNo].id,
												event_link: calEvents[evNo].htmlLink 
											});	
			evNo++;
		}

		if(isOldEvent && evNo==calEvents.length){
			cal_html += "</div>";
			isOldEventsDivClosed = true;					
			cal_html += this.NO_FUTURE_EVENT_FOR_TICKET_MSG.evaluate({});
		}

		if(evNo == (calEvents.length-1) && otherTicketEventsDivOpen){
				cal_html += "</div></div>";
				otherTicketEventsDivOpen = false;
		}


		jQuery("#google_calendar_events_container").html(cal_html);

		if(pastEventsDisplayed) jQuery("#gcal-old-events").show();
		if(otherTicketEventsDisplayed) jQuery("#gcal-old-events").show();
		this.bindEvents();
	},

	bindEvents: function(){
		// Used when Events View is repopulated.
		jQuery('.event').mouseenter(function(){ if(gcal.isEventWritable(jQuery(this).find('span.edit-delete-event a[href=\'#delete_event\']').attr('evid'))) jQuery(this).find('span.edit-delete-event').fadeIn(50); })
						.mouseleave(function(){ if(gcal.isEventWritable(jQuery(this).find('span.edit-delete-event a[href=\'#delete_event\']').attr('evid'))) jQuery(this).find('span.edit-delete-event').fadeOut(50); });
		jQuery("a[href='#delete_event']").click(function(e){	
			var evid=jQuery(this).attr("evid");
			e.preventDefault();
			confirmDelete("Confirm Delete", "Are you sure want to delete the event \"" + gcal.getEventById(evid).summary + "\" ?",
						"Delete", "Cancel", gcal.deleteEvent, [gcal, [evid]]);
		}).disableSelection();
		jQuery("a[href='#edit_event']").click(function(e){e.preventDefault(); showAddEditDialog(jQuery(this).attr('evid'));}).disableSelection();
		jQuery("#gcal-other-events-link-container").click(function(e){
			e.preventDefault();
			animatingOtherTicketEvents = true;
			if(!otherTicketEventsDisplayed){
				jQuery("#gcal-other-tickets-events-container").slideDown({duration: ANIMATION_TIME, easing: '', complete: function(){
						otherTicketEventsDisplayed = true;
						animatingOtherTicketEvents = false;
					}});
				jQuery("#gcal-other-tickets-arrow").removeClass("arrow-right").addClass("arrow-down");
			} else {
				jQuery("#gcal-other-tickets-events-container").slideUp({duration: ANIMATION_TIME, easing: '', complete: function(){
						otherTicketEventsDisplayed = false;
						animatingOtherTicketEvents = false;
					}});
				jQuery("#gcal-other-tickets-arrow").removeClass("arrow-down").addClass("arrow-right");
			}
		}).disableSelection();
	},

	getCalId: function(evid){
		if(gcal.event_id_to_calendar_id[evid])
			return gcal.event_id_to_calendar_id[evid];
		var evl = google_calendar_options.events_list;
		for(i=0; i<evl.length; i++){
			evId_calId = evl[i].remote_integratable_id.split(':');
			if(evId_calId[1] == evid)
				return evId_calId[0];
		}		
		return null;
	},

	getEventIndexById: function(eventId){
		for(i=0; i<this.calEvents.length; i++)
			if(this.calEvents[i].id == eventId)
				return i;
		return null;
	},

	getEventById: function(eventId){ 
		i = this.getEventIndexById(eventId);
		return i!=null ? this.calEvents[i] : null;
	},

	isThisTicketEvent: function(eventId){
		for(i=0; i<google_calendar_options.events_list.length; i++)
			if(google_calendar_options.events_list[i].remote_integratable_id.split(':')[1] == eventId)
				return true;
		for(i=0; i<gcal.calEvents.length; i++)
			if(gcal.calEvents[i].id == eventId  &&  !gcal.calEvents[i].isOfOtherTicket)
				return true;
		return false;
	},
	
	isEventWritable: function(evid){
		calId = gcal.getCalId(evid);
		cal = gcal.calendarsById[calId]
		return (cal && jQuery.inArray(cal.accessRole, ["writer", "owner"])>=0 && gcal.isThisTicketEvent(evid));
	},

	eventExistsTomorrowOrLater: function(){
		for(i=0; i<this.calEvents.length; i++)
			if(isFutureEvent(this.calEvents[i]) && !isEventToday(this.calEvents[i]))
				return true
		return false;
	},


	getDateTime: function(timeFieldText, dateFieldText){
		txt = timeFieldText;
		time_array = trimArray(txt.split(':'));
		hrs = time_array[0]*1; mins=parseInt(time_array[1])*1;
		if(time_array.length!=2 || time_array[0].length == 0 || time_array[1].length==0)
			return null;
		if(!hrs || isNaN(hrs) || hrs>12 || hrs<1)
			return null;
		if(isNaN(mins) || mins<0 || mins>59)
			return null;
		d=dateFieldText.split('-');
		dd=d[0]; mm=d[1]-1; yy=d[2];
		if(txt.toLowerCase().indexOf('pm')!='-1'){ if(hrs!=12) hrs+=12;}
		else if(hrs == 12) hrs=0;
		return (new Date(yy, mm, dd, hrs, mins, 0, 0));
	},

	getStartDateTime: function(){
		return gcal.getDateTime( jQuery("#gcal-start-time-field").val(),
						jQuery("#gcal-start-date-alt-field").val() );
	},

	getEndDateTime: function(){
		return gcal.getDateTime( jQuery("#gcal-end-time-field").val(),
						jQuery("#gcal-end-date-alt-field").val() );
	},

	setTime: function(dObj, id){
		hrs = dObj.getHours();
		mins = dObj.getMinutes();
		
		meridian = (hrs<12 ? "am":"pm"); 
		// AM/PM will toggle & styled during .click() (Last line of method)
		
		hrs = hrs % 12;
		if(hrs == 0) hrs = 12;
		if(hrs < 10) hrs = '0'+hrs;
		if(mins < 10) mins = '0'+mins;
		jQuery("#"+id).val(hrs + ':' + mins + ' ' + meridian);
	},

	setStartDateTime: function(dObj){
		jQuery("#gcal-start-date-field").datepicker('setDate', dObj);
		gcal.setTime(dObj, "gcal-start-time-field");
		onStartDateTimeChanged();
	},

	setEndDateTime: function(dObj){
		// jQuery("#end_date_field").datepicker('setDate', dObj);
		jQuery("#gcal-end-date-alt-field").val(dObj.getDate() + '-' + (dObj.getMonth()+1) + '-' + dObj.getFullYear());
		gcal.setTime(dObj, "gcal-end-time-field");
		onEndDateTimeChanged();
	},


	renderEditForm: function(eventId){
		// Set "Edit Event" form's fields' values
		ev = gcal.getEventById(eventId);
		startDateTime = new Date();
		startDateTime.setTime(Date.parseISO8601(ev.start.dateTime));
		endDateTime = new Date();
		endDateTime.setTime(Date.parseISO8601(ev.end.dateTime));
		gcal.setStartDateTime(startDateTime);
		gcal.setEndDateTime(endDateTime);
		jQuery('#gcal-event-summary').val(ev.summary);
		jQuery('#google_calendar_event_description').val(ev.description);
		jQuery('#gcal-calendar-list option[value=\''+gcal.getCalId(eventId)+'\']').attr("selected", "selected");
		jQuery('#gcal-submit-event-button').val('Update');
	},

	renderAddForm: function(){
		startDateTime = new Date();
		mins = startDateTime.getMinutes();
		mins = mins - mins%30 + 60;
		startDateTime.setMinutes(mins);
		endDateTime = new Date(startDateTime.getTime());
		addMinutes(endDateTime, gcal.duration || 60);
		gcal.setStartDateTime(startDateTime);
		gcal.setEndDateTime(endDateTime);
		jQuery('#gcal-event-summary').val('');
		jQuery('#google_calendar_event_description').val('');
		jQuery('#gcal-submit-event-button').val('Add Event');
	}
};

function confirmDelete(dTitle, dContent, y, n, callback, args){
	jQuery("div.confirm-modal-content").html(dContent);
	jQuery('#gcal-confirm-modal')
	 	.removeClass("hide")
	 	.dialog({ 
	      title: dTitle, 
	      buttons: [{text: y, 'class': "confirm-modal-yes-button hide btn btn-primary", click: function(){
							jQuery(this).dialog('close');
							callback.apply(args[0], args[1]);
						}
					},
	      			{text: n, 'class': "confirm-modal-no-button hide btn", click: function(){jQuery("#gcal-confirm-modal").dialog('close');}}],
	      show: {	effect: "fade", duration: 200, complete: function(){} },
	      create: function(evt, ui){
	      	jQuery(".confirm-modal-yes-button").blur();
	      },
	      width: '320px', height: '300px', modal: true, resizable: false 
    });	
 	jQuery("#gcal-confirm-modal").css({'min-height': '30px'});
	jQuery(".confirm-modal-yes-button, .confirm-modal-no-button").show();
}

MONTH = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
DAY = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
ANIMATION_TIME = 300;
SEARCH_KEYWORD = 'FreshdeskTicket';
DEFAULT_EVENT_DURATION = 60; // Minutes;


// Utility functions regarding dates/events etc.
	function zeroDate(){ return (new Date()).setTime(0); }
	function addHours(date, hours){ return (date.setHours(date.getHours() + hours));}
	function addMinutes(date, minutes){ return (date.setMinutes(date.getMinutes() + minutes));}
	function isFutureEvent(ev){ return Date.parseISO8601(ev.start.dateTime) > ((new Date()).getTime()); }
	function isEventToday(ev){ return isEventOn(ev, new Date()); }
	function isEventTomorrow(ev){ return isEventOn(ev, addHours(new Date(), 24)); }
	function isEventYesterday(ev){ return isEventOn(ev, addHours(new Date(), -24)); }
	function isEventOn(ev, date){
		date = new Date(date);
		date.setHours(0); date.setMilliseconds(0); date.setMinutes(0); date.setSeconds(0);
		date_ms = date.getTime();
		ev_ms = Date.parseISO8601(ev.start.dateTime);
		return (ev_ms>=date_ms && ev_ms<(date_ms+86400000));
	}
	function formatEventTime(start, end){
		start_d = new Date(); start_d.setTime(Date.parseISO8601(start.dateTime));
		hrs = start_d.getHours();
		mins = start_d.getMinutes();
		if(hrs > 12){ am_or_pm = "pm"; hrs -= 12; } else { am_or_pm = "am"; }
		s =  (hrs<10?'0':'') + hrs + ":" + (mins<10?'0':'') + mins + ' ' + am_or_pm;

		if(end){
			end_d = new Date(); end_d.setTime(Date.parseISO8601(end.dateTime));
			hrs = end_d.getHours();
			mins = end_d.getMinutes();
			if(hrs>12){am_or_pm = "pm"; hrs-=12;} else { am_or_pm = "am"; }
			s += " - " + (hrs<10?'0':'') + hrs + ":" + (mins<10?'0':'') + mins + ' ' + am_or_pm;
		}
		return s;
	}	
	function parseTimeString(query, meridianObject){
		var meridian = null;
		query = ' ' + query;
		q1 = query.replace( /[^\d]*/i, '' ); // Remove non digits
		hrs = parseInt(q1); // Parse hours
		q2 = query.replace( /[^\d]*\d*[^\d]*/i, '' ); // Remove digits & following non-digits
		mins = parseInt(q2); // Parse mins
		q2 = q2.toLowerCase();
		if(q2.indexOf('am')!=(-1)) meridian = 'am';
		else if(q2.indexOf('pm')!=(-1)) meridian = 'pm';
		else if(q2.indexOf('a')!=(-1)) meridian = 'am';
		else if(q2.indexOf('p')!=(-1)) meridian = 'pm';
		else if(q1.indexOf('am')!=(-1)) meridian = 'am';
		else if(q1.indexOf('pm')!=(-1)) meridian = 'pm';
		else if(q1.indexOf('a')!=(-1)) meridian = 'am';
		else if(q1.indexOf('p')!=(-1)) meridian = 'pm';
		// else meridian='am';
		if(hrs<0 || hrs>23) return null;	
		if(hrs == 0) {meridian='am'; hrs=12;}
		if(hrs > 12) {meridian = 'pm'; hrs-=12;}
		if(meridian){
			if(typeof meridianObject != 'undefined')
				meridianObject.meridian = meridian;
		} else { 
			meridian = 'am';
		}
		if(isNaN(mins)) mins = 0;
		if(mins<0 || mins>59) return null;
		if(mins<10) mins = '0'+mins;
		if(!isNaN(hrs))
			return hrs + ':' + mins + ' ' + meridian;
		return null;
	}
	function findNearestHalfHour(query, forEndTime){
		var meridianObject = {meridian: null};
		t = parseTimeString(query, meridianObject);
		if(!t) return null;
		t = t.split(' ');
		hm = t[0].split(':');
		h = hm[0]*1; m = hm[1]*1;
		if(forEndTime){
			startDateTime = gcal.getStartDateTime();
			if(startDateTime){
				h_start_24 = startDateTime.getHours();
				h_start = h_start_24;
				if(h_start > 12) h_start -= 12;
				else if(h_start == 0) h_start=12;
			}
			if(h_start == h){
				if(m<30 || (m==30 && h!=12))
					m=30;
				else {++h; m=0;}
				if(h == 13) h=1;
				hm[0]=h; hm[1]=m;
			}
			if(meridianObject.meridian==null && startDateTime){
				h_end = h;
				if(h_end >= h_start) t[1] = (h_start_24>12 && h_end!=12)?'pm':'am';
				else  t[1] = (h_start_24>12 && h_end!=12)?'am':'pm';
			}
		}
		if(m>=30){return parseTimeString(h+':30 '+t[1]);}
		else return h + ':00 ' + t[1];
		// else return t.join(' ').replace( /:\d*/, ':00' )
	}
	function showAddEditDialog(eventId){
		var timeList=[	'12:00 am', '12:30 am', '1:00 am', '1:30 am', '2:00 am', '2:30 am', '3:00 am', '3:30 am', '4:00 am', '4:30 am', '5:00 am', '5:30 am',
						'6:00 am', '6:30 am', '7:00 am', '7:30 am', '8:00 am', '8:30 am', '9:00 am', '9:30 am', '10:00 am', '10:30 am', '11:00 am', '11:30 am', 
						'12:00 pm', '12:30 pm', '1:00 pm', '1:30 pm','2:00 pm', '2:30 pm','3:00 pm', '3:30 pm','4:00 pm', '4:30 pm','5:00 pm', '5:30 pm',
						'6:00 pm', '6:30 pm','7:00 pm', '7:30 pm','8:00 pm', '8:30 pm','9:00 pm', '9:30 pm','10:00 pm', '10:30 pm','11:00 pm', '11:30 pm',
					];

		gcal.updatingEvent_id = eventId;
		bodyScrollTop = jQuery('body').scrollTop();
		jQuery('#gcal-validation-errors').hide();
		jQuery('#google_calendar_add_event_modal').dialog({ 
	      show: {	effect: 'fade', complete: function(){
	      				// jQuery('body').scrollTop(bodyScrollTop);
	      				// jQuery('#google_calendar_add_event_modal').parent().position({top: 0});
			      		jQuery("#gcal-start-time-field, #gcal-end-time-field").typeahead({
							source: timeList,
							items: 48,
							scrollable: true,
							matcher: function(item){
								if( /.*\d.*/ig.match(item) ) return true;
								return false;
							},
							sorter: function(items){
								items.sort(function(a, b){
									a_arr = a.split(':');
									hrs = parseInt(a_arr[0]);
									mins = parseInt(a_arr[1]);
									isAM = (a.indexOf("am")!=(-1));
									if(hrs == 12) { if(isAM) hrs = 0; }
									else if(!isAM)  hrs += 12;
									x = hrs*60 + mins;
									b_arr = b.split(':');									
									hrs = parseInt(b_arr[0]);
									mins = parseInt(b_arr[1]);
									isAM = (b.indexOf("am")!=(-1));
									if(hrs == 12){ if(isAM) hrs = 0; }
									else if(!isAM) hrs += 12;
									y = hrs*60 + mins;
									return x-y;
								});
								return items;
							},
							highlighter: function(item){
							    var query = this.query.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, '\\$&');
							    return item.replace(new RegExp('(' + query + ')', 'ig'), function ($1, match) {
							        return '<span>' + match + '</span>';
						      	});
							},
							onComplete: function(){
								this.$menu.find("li.active").removeClass('active');
								best_match = findNearestHalfHour(this.query, (this.$element.attr('id')=='gcal-end-time-field') );

								gcal.menuItem = this.$menu;
								if(best_match){

									setTimeout(function(){
										target = this.$menu.find('li[data-value="' + best_match + '"]').addClass('active');
										target.parent().scrollTop(target.position().top+target.parent().scrollTop())

									}.bind(this), 20);
									// if(target) 
									// jQuery(target.parentNode).scrollTop(jQuery(target.parentNode).scrollTop() + jQuery(target).offset().top);

								} else {
									this.hide();
								}
							}
						});
						jQuery('.typeahead').css({'z-index': '1010', 'overflow': 'scroll', 'max-height': '150px'});
						jQuery('#gcal-event-summary').focus();
						jQuery("#gcal-add-update-modal-cancel-button").click(function(){
							jQuery("#google_calendar_add_event_modal").dialog("close");
						}).disableSelection();
			        }
		  },
	      title: eventId ? "Edit event" : "Add event", 
	      width: '500px', height: 'auto',
	      modal: true, resizable: false , position: 'top',
	      beforeClose: function(evt, ui){
	      	if(gcal.preventDialogClose) return false;
	      	jQuery("#google_calendar_add_event_modal .gcal-custom-errors").hide();
	      	jQuery("#gcal-start-date-field").datepicker('hide');
	      	jQuery("#add_event_link").focus();
	      	return true;
	      }
	    });

	    if(eventId) 
	    	gcal.renderEditForm(eventId);
		else { 
			gcal.renderAddForm();
		};
	}
	function getMaxTimeToday(){
		d = new Date();
		d.setHours(23);
		d.setMinutes(59);
		d.setSeconds(59);
		d.setMilliseconds(999);
		return d;
	}
	function getMinTimeToday(){
		d = new Date();
		d.setHours(0);
		d.setMinutes(0);
		d.setSeconds(0);
		d.setMilliseconds(0);
		return d;
	}

var pastEventsDisplayed = false, otherTicketEventsDisplayed = false;
var animatingOldEvents = false, animatingOtherTicketEvents = false;
easing_function = "easeInOutCubic"

jQuery(document).ready(function(){

	var gcal = new GoogleCalendar(google_calendar_options);
	

	add_edit_event_modal_html = gcal.ADD_EDIT_EVENT_TEMPLATE.evaluate({
															 calendarOptions: (gcal.calendarOptions || 														
																'<option value="">Loading...</option>'),
															 })
														+ gcal.GCAL_CONFIRM_MODAL.evaluate({});
	
	jQuery('body').append(add_edit_event_modal_html);
	jQuery('#gcal-add-event-form').find('input[type="text"], select').each(function(index){
		jQuery(this).attr('name', jQuery(this).attr('id'));
	});
	// jQuery('#gcal-add-event-form').
	
	jQuery("#gcal-older-events-link, #gcal-older-events-arrow").click(function(e){
		e.preventDefault();
		animatingOldEvents = true;
		link = jQuery("#gcal-older-events-arrow");
		if(pastEventsDisplayed)	{
			link.removeClass("arrow-down").addClass("arrow-right");
			jQuery('#gcal-old-events').slideUp({duration: ANIMATION_TIME, easing: '', complete: function(){
						pastEventsDisplayed = false;
						animatingOldEvents = false;
					}.bind(this) });
		} else {
			link.removeClass("arrow-right").addClass("arrow-down");
			jQuery('#gcal-old-events').slideDown({duration: ANIMATION_TIME, easing: '', complete: function(){
						pastEventsDisplayed = true;
						animatingOldEvents = false;
					}.bind(this) });
		}
	}).disableSelection();

	jQuery("#add_event_link").click(function(e){e.preventDefault(); showAddEditDialog();}).disableSelection();

	onStartDateTimeChanged = function(){
		startDateTime = gcal.getStartDateTime();
		if(typeString(startDateTime) != 'date') return;
		gcal.startTimeSelected = true;

		if(!gcal.duration) gcal.setEndDateTime(startDateTime);
		else {
			if(gcal.duration<=0) return;

			nHrs = Math.floor(gcal.duration/60);
			nMins = gcal.duration%60;
			jQuery("#gcal-event-duration").html((nHrs?(nHrs+" hr "):"") + nMins + " mins");
			s = startDateTime;
			s.setMinutes(s.getMinutes()+gcal.duration); // Duration is in minutes
			gcal.setEndDateTime(s);
		}
	};

	onEndDateTimeChanged = function(){
		if(gcal.startTimeSelected){
			s = gcal.getStartDateTime();
			e = gcal.getEndDateTime();
			if(typeString(s)!='date' || typeString(e)!='date')
				return;


			gcal.duration = (e.getTime()-s.getTime())/(1000*60); // To minutes
			if(gcal.duration < 0){
				gcal.duration += (24*60);
				addMinutes(s, gcal.duration);
				gcal.setEndDateTime(s);
			} else if(gcal.duration >= (24*60)){
				gcal.duration -= (24*60);
				addMinutes(s, gcal.duration);
				gcal.setEndDateTime(s);
			}
			nHrs = Math.floor(gcal.duration/60);
			nMins = gcal.duration%60;
			jQuery("#gcal-event-duration").html((nHrs?(nHrs+" hr "):"") + nMins + " mins");
		}	
	};
	
	jQuery("#gcal-start-time-field, #gcal-end-time-field").click(function(){
		e = jQuery.Event('keyup');
		e.which = e.code = 65;
		jQuery(this).trigger(e);
	}).disableSelection();


	var date_today = new Date();
	datepicker_configs = {
		changeMonth: true, 
		changeYear: true,
		numberOfMonths: 1,
		dateFormat: "D, M d, yy",
		showButtonPanel: false,
		minDate: "today",
		showOn: "focus",
		altField: "#gcal-start-date-alt-field", 
		altFormat: "dd-mm-yy",
		disabled: true,
		onSelect: function(){onStartDateTimeChanged(); jQuery('#gcal-start-time-field').focus().trigger(jQuery.Event('click'))}
	};

	var dates = jQuery("#gcal-start-date-field").datepicker(datepicker_configs);
	gcal.duration = DEFAULT_EVENT_DURATION;

	jQuery("#gcal-start-time-field, #gcal-end-time-field").change(function(){
		var elemId = jQuery(this).attr('id');
		var mObj = {};
		var s = parseTimeString(jQuery(this).val(), mObj);
		if(s){
			if(!mObj.meridian){
				if(elemId == "gcal-end-time-field"){
					var t_end = s.split(':');
					var h_end = parseInt(t_end[0]), m_end = parseInt(t_end[1]);
					var t_start = jQuery("#gcal-start-time-field").val();
					if(jQuery.validator.methods.time_12(t_start)){
						t_start = t_start.split(':');
						var h_start = parseInt(t_start[0]), m_start = parseInt(t_start[1]);
						s = s.replace(/[ap]/, t_start[1].charAt(t_start[1].length-2))
						if(((h_end<h_start || (h_end==h_start && m_end<m_start)) && h_start!=12) || 
																			(h_start<12 && h_end==12)){
							if( s.indexOf('a') != (-1) )
								s = s.replace(/a/, 'p');
							else
								s = s.replace(/p/, 'a');
						}
					}
				} else if(elemId == "gcal-start-time-field"){
					var hrs = parseInt(jQuery(this).val());
					if((hrs>=1 && hrs<=6) || hrs==12) s=s.replace(/a/, 'p');
				}
			}
			jQuery(this).val(s);
		}
		if(elemId == "gcal-start-time-field") onStartDateTimeChanged();
		else if(elemId == "gcal-end-time-field")  onEndDateTimeChanged();
		e = jQuery.Event('click');
		jQuery(this).trigger(e);
	});

	jQuery("#gcal-add-event-form").validate({
		submitHandler: function(){gcal.submitForm();},
		onsubmit: true,
		errorLabelContainer: "#gcal-validation-errors",
		errorContainer: "#gcal-validation-errors ul",
		wrapper: "li",
		messages: {
			'gcal-event-summary': {required: "Please specify title of the event."},
			'gcal-start-time-field': {
				required: "Event start time is required.",
				'time-12': "Invalid start time."
		    },
		    'gcal-end-time-field': {
				required: "Event end time is required.",
				'time-12': "Invalid end time."
		    },
		    'gcal-calendar-list': {
		    	required: "Invalid calendar. Please wait for list of calendars to load and select one."
		    }
	 	},
	 	onfocusout: false
	 });


});

if(google_calendar_options.oauth_token && google_calendar_options.oauth_token!='')
	jQuery("#gcal-email-container, #gcal-change-account-link").show();
		

jQuery("#gcal-change-account-link, #gcal-authorize-link").click(function(e){
	jQuery.cookie('return_uri', document.location.href, {path: '/'});
});
/**
 * Date.parse with progressive enhancement for ISO 8601 <https://github.com/csnover/js-iso8601>
 * © 2011 Colin Snover <http://zetafleet.com>
 * Released under MIT license.
 */
(function (Date, undefined) {
    var origParse = Date._parse, numericKeys = [ 1, 4, 5, 6, 7, 10, 11 ];
    Date.parseISO8601 = function (date) {
        var timestamp, struct, minutesOffset = 0;

        // ES5 §15.9.4.2 states that the string should attempt to be parsed as a Date Time String Format string
        // before falling back to any implementation-specific date parsing, so that’s what we do, even if native
        // implementations could be faster
        //              1 YYYY                2 MM       3 DD           4 HH    5 mm       6 ss        7 msec        8 Z 9 ±    10 tzHH    11 tzmm
        if ((struct = /^(\d{4}|[+\-]\d{6})(?:-(\d{2})(?:-(\d{2}))?)?(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{3}))?)?(?:(Z)|([+\-])(\d{2})(?::(\d{2}))?)?)?$/.exec(date))) {
            // avoid NaN timestamps caused by “undefined” values being passed to Date.UTC
            for (var i = 0, k; (k = numericKeys[i]); ++i) {
                struct[k] = +struct[k] || 0;
            }

            // allow undefined days and months
            struct[2] = (+struct[2] || 1) - 1;
            struct[3] = +struct[3] || 1;

            if (struct[8] !== 'Z' && struct[9] !== undefined) {
                minutesOffset = struct[10] * 60 + struct[11];

                if (struct[9] === '+') {
                    minutesOffset = 0 - minutesOffset;
                }
            }

            timestamp = Date.UTC(struct[1], struct[2], struct[3], struct[4], struct[5] + minutesOffset, struct[6], struct[7]);
        }
        else {
            timestamp = origParse ? origParse(date) : NaN;
        }

        return timestamp;
    };
}(Date));

	function padzero(n) {
		return n < 10 ? '0' + n : n;
	}
	function pad2zeros(n) {
		if (n < 100) {
		n = '0' + n;
		}
		if (n < 10) {
		n = '0' + n;
		}
		return n;     
	}
	Date.prototype.toISO8601 = function () {
		var d = this;
		return d.getUTCFullYear() + '-' +  padzero(d.getUTCMonth() + 1) + '-' + padzero(d.getUTCDate()) + 'T' + padzero(d.getUTCHours()) + ':' +  padzero(d.getUTCMinutes()) + ':' + padzero(d.getUTCSeconds()) + '.' + pad2zeros(d.getUTCMilliseconds()) + 'Z';
	};


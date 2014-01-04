/*
 * @author venom
 */

var TicketTimesheet = Class.create();
TicketTimesheet.prototype = {
  initialize: function(initList, _options) {
    this.editid  = null;     
     // Running the autoupdate for the timer when it is active.
     new PeriodicalExecuter(function(pe) {
        jQuery(".time_running .time")
         .each(function(){
            var seconds = jQuery(this).data('runningTime') + 1;
            jQuery(this)
               .html(time_in_hhmm(seconds))
               .data('runningTime', seconds);                	    
            });
            totalTime("#timesheetlist .time", "#timeentry_timer_total");
         }, 1);
         
         jQuery("#timesheetlist div.timeentry")
              .livequery( this.timeCount, this.timeCount );

         jQuery('a.submit').live("click", function(ev){
           ev.preventDefault();

           if (jQuery("#timeentry_apps_add .app-logo input[type=checkbox]").filter(':checked').parentsUntil('#time_integration').filter(".still_loading").length) {
             return false;
           }

           jQuery(this).button("loading");

           if(!jQuery(this).hasClass("disabled"))
               jQuery(this).parents("form").submit();		
         });
        
        jQuery("#add_new_time_entry #time_entry_hours")
           .bind("keyup", function(ev){
              if(jQuery(this).val().strip() != ""){
                 jQuery("#add_new_time_entry #new_time_submit").html("Save");
              }else{
                 jQuery("#add_new_time_entry #new_time_submit").html("Start timer");
              }
           }); 
        
        if(jQuery("#timesheetlist .timeentry").size() == 0 || jQuery("#TimeSheetButton").hasClass('active')){ 
           jQuery('#timeentry_add').addClass("active_edit");
         }
         
        jQuery("#TimeSheetButton").click(function(ev){
           jQuery('#TimesheetTab').click();
           timesheet.clearEdit();
           timesheet.editCompelete("add");    
           jQuery('#add_new_time_entry').get(0).reset();
			  jQuery("#new_time_submit").button('reset').html("Start timer");
		     if (typeof harvestWidget != 'undefined' && harvestWidget) 
		   		harvestWidget.resetIntegratedResourceIds()
		     if (typeof freshbooksWidget != 'undefined' && freshbooksWidget) 
		   		freshbooksWidget.resetIntegratedResourceIds()
         if (typeof workflowMaxWidget != 'undefined' && workflowMaxWidget) 
          workflowMaxWidget.resetIntegratedResourceIds()
        });

    // //Positioning the button container below the integration widgets
    // var widgets_height = jQuery("#timeentry_apps_add").height();
    // var buttons_height = jQuery("#timeentry_add .request_panel.timeentry_edit .button-container").height();
    // jQuery("#timeentry_add .request_panel.timeentry_edit .button-container").css({top:widgets_height + 25});
    // jQuery("#timeentry_apps_add").css({top:-buttons_height});

    // console.log('Positioning done. ');
     
  },

  editCompelete: function(id, dontshow) { 
     this.clearEdit();
     if(!dontshow)
      jQuery('#timeentry_'+id).addClass("active_edit");
     jQuery('#time_integration').detach().appendTo('#timeentry_apps_'+id);
  },
  
  clearEdit: function(){
     jQuery('#Timesheet .active_edit').removeClass("active_edit");
  },
  
  timeCount: function(){
      var count = jQuery("#timesheetlist div.timeentry").size();  
      jQuery("#TimesheetCount").html(count);
      jQuery("#TimesheetCount, #timesheettotal").toggle(count != 0)
      jQuery("#timesheetlist div.list-noinfo").hide();
      totalTime("#timesheetlist .time", "#timeentry_timer_total");
  }
};
var timesheet = new TicketTimesheet();	

jQuery("#time_integration .app-logo").live('click',function(ev) {
  if (!jQuery(ev.target).is('input[type=checkbox]')) {
    var checkbox = jQuery(this).children("input[type=checkbox]");
    checkbox.prop('checked', !checkbox.prop('checked'));
  }
});

jQuery(document).on('localstorage_changed_timeRunning', function(ev, data) {
  var new_value = JSON.parse(data.newValue), 
      old_id = parseInt(jQuery('#header_active_timeentry').data('timeentryId'));

  if(!new_value.isRunning || (new_value.id != old_id && new_value.isRunning)){
    jQuery("#header_timer").empty();
    change_time_sheet(old_id);
  }

});

function change_time_sheet(id){
  if(jQuery("#TimesheetTab").length > 0){ 
    var timer_dom = jQuery("#timeentry_"+id+" .toggle_timer");
    jQuery("#timeentry_"+id).removeClass('time_running');    
    timer_dom.html(timer_dom.data('startText'));
    jQuery('#timesheetlist .time-tracked-details:last .toggle_timer').css("display", "inline");
  }
}

function fill_hours(time, hideHeader){
  jQuery('.modal.in #time_entry_hhmm').val(time);
  jQuery('.modal.in #time_entry_hhmm').select();
  
  if (hideHeader) {
    jQuery('.header-timer').addClass('stop-timer');
  }
}

function update_localstorage(id, timer_running){
  var hash_data = {
      id : id,
      isRunning : timer_running,
  }
  storeInLocalStorage('timeRunning', hash_data);
}
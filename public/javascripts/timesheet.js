/*
 * @author venom
 */

var TicketTimesheet = Class.create();
TicketTimesheet.prototype = {
  initialize: function(initList, _options) {
    this.editid  = null;     
     // Running the autoupdate for the timer when it is active.
     new PeriodicalExecuter(function(pe) {
        jQuery("div.time_running .time")
         .each(function(){
            seconds = jQuery(this).data('runningTime');
            timeout = 10 - seconds % 10;
            jQuery(this)
               .html(sprintf( "%0.02f", seconds/3600))
               .data('runningTime', seconds+timeout);                	    
            });
            totalTime("#timesheetlist .time", "#timeentry_timer_total");
         }, 10);
         
         jQuery("#timesheetlist div.timeentry")
              .livequery( this.timeCount, this.timeCount );

         jQuery('a.submit').live("click", function(ev){
           ev.preventDefault();
           if (jQuery("#time_integration .integration.still_loading").length) {
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
        });

        jQuery("#timeentry_apps_add .app-logo").live('click',function(ev) {
          var checkbox = jQuery(this).children("input[type=checkbox]");
          checkbox.prop('checked', !checkbox.is(':checked'));
        });

    //     console.log('Positioning the buttons');

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
      count = jQuery("#timesheetlist div.timeentry").size();  
      jQuery("#TimesheetCount").html(count);
      jQuery("#TimesheetCount, #timesheettotal").toggle(count != 0)
      jQuery("#timesheetlist div.list-noinfo").hide();
      totalTime("#timesheetlist .time", "#timeentry_timer_total");
  }
};
var timesheet = new TicketTimesheet();	
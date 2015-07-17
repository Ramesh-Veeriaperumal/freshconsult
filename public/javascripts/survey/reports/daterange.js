/*
    Module deals with events associated with date range.
*/
var SurveyDateRange = {
    isInitialized: false,
    updateLink:function(dateRange){
        jQuery("#survey_date_range_link").text(jQuery("#survey_date_range").val());
    },
    init:function(){
        if(!this.isInitialized){
                jQuery("#survey_date_range").val(dateRange);
                this.updateLink();
                this.isInitialized=true;
        }
        jQuery("#survey_date_range").attr("values",Date.today().toString("dddd, MMMM dd yyyy"));
        jQuery("#survey_date_range").bootstrapDaterangepicker({
            format: "DD MMM, YYYY",
            minDate: Date.parse('04/01/2013'),
            maxDate: Date.parse('Today'),
            closeOnSelect: true
        });
        jQuery('#survey_date_range').on('apply.bootstrapDaterangepicker', function(ev, picker) {
              jQuery("#survey_date_range_link").text(jQuery("#survey_date_range").val());
              SurveyState.fetch();
              SurveyDateRange.close();
        });
        jQuery('#survey_date_range').on('cancel.bootstrapDaterangepicker', function(ev, picker) {
              SurveyDateRange.close();
        });
        jQuery('body').on('mousedown', function(ev) {
              SurveyDateRange.close();
        });
    },
    open:function(){
        jQuery("#survey_date_link_container").hide();
        jQuery("#survey_date_text_container").show();
        jQuery("#survey_date_range").focus();
        jQuery(".daterangepicker").addClass("survey_date_range");
    },
    close:function(){
       jQuery("#survey_date_text_container").hide();
       jQuery("#survey_date_link_container").show();
       jQuery(".daterangepicker").removeClass("survey_date_range");
    },
    convertDateToTimestamp:function(date){
        var dateArray = date.split("-");
        var fromTimestamp = new Date(dateArray[0]).getTime() /1000;
        var toTimestamp   = new Date(dateArray[1]).getTime() /1000;
        var timestamp = fromTimestamp + "-" + toTimestamp;
        return timestamp;
    },
    convertTimestampToDate: function(timestamp){
        var formatDate = function(date){
            return date.getDate()+ " " + SurveyI18N.month_names[(date.getMonth()+1)]+", "+(date.getYear()+1900);
        }
        var dateArray = timestamp.split("-");
        var fromDate  = new Date(parseInt(dateArray[0])*1000);
        var toDate    = new Date(parseInt(dateArray[1])*1000);
        fromDate  = formatDate(fromDate);
        toDate    = formatDate(toDate);
        var dateRange = fromDate + "-" + toDate;
        return dateRange;
    }
}

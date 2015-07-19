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
        var fromTimestamp = (("0" + (new Date(dateArray[0]).getDate())).slice(-2))  + "" + (("0" + (new Date(dateArray[0]).getMonth()+1)).slice(-2)) + "" +
                            (new Date(dateArray[0]).getYear()+1900);
        var toTimestamp   = (("0" + (new Date(dateArray[1]).getDate())).slice(-2)) + "" + (("0" + (new Date(dateArray[1]).getMonth()+1)).slice(-2)) + "" +
                            (new Date(dateArray[1]).getYear()+1900);
        var timestamp = fromTimestamp + "-" + toTimestamp;
        return timestamp;
    },
    convertTimestampToDate: function(timestamp){
        var formatDate = function(date){
            return date.substring(0,2)+ " " + SurveyI18N.month_names[(parseInt(date.substring(2,4)))]+", "+(date.substring(4,8));
        }
        var dateArray = timestamp.split("-");        
        fromDate  = formatDate(dateArray[0]);
        toDate    = formatDate(dateArray[1]);
        var dateRange = fromDate + "-" + toDate;
        return dateRange;
    }
}

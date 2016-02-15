/*
    Module deals with events associated with date range.
*/
var SurveyDateRange = {
    isInitialized: false,
    month_names: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    updateLink:function(dateRange){
        var timestamp = SurveyDateRange.convertDateToTimestamp(jQuery("#survey_date_range").val());
        var dateRange = SurveyDateRange.convertTimestampToDate(timestamp);
        jQuery("#survey_date_range_link").text(dateRange);
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
              var timestamp = SurveyDateRange.convertDateToTimestamp(jQuery("#survey_date_range").val());
              var dateRange = SurveyDateRange.convertTimestampToDate(timestamp);
              jQuery("#survey_date_range_link").text(dateRange);
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
    },
    convertDateToTimestamp:function(date){
        var dateArray = date.split("-");
        var d_from = new Date(dateArray[0]);
        var d_to = new Date(dateArray[1]);
        var fromTimestamp = (("0" + (d_from.getDate())).slice(-2))  + "" + (("0" + (d_from.getMonth()+1)).slice(-2)) + "" +
                            (d_from.getYear()+1900);
        var toTimestamp   = (("0" + (d_to.getDate())).slice(-2)) + "" + (("0" + (d_to.getMonth()+1)).slice(-2)) + "" +
                            (d_to.getYear()+1900);
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
    },
    convertTimestampToDateEn: function(timestamp){
        var formatDate = function(date){
            return date.substring(0,2)+ " " + SurveyDateRange.month_names[(parseInt(date.substring(2,4))-1)]+", "+(date.substring(4,8));
        }
        var dateArray = timestamp.split("-");        
        fromDate  = formatDate(dateArray[0]);
        toDate    = formatDate(dateArray[1]);
        var dateRange = fromDate + "-" + toDate;
        return dateRange;
    }
}

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
        jQuery("#survey_date_range").daterangepicker({
            earliestDate: Date.parse('1/1/2009'),
            latestDate: new Date(),
            format: "DD MMM, YYYY",
            presetRanges: [
                {text: SurveyI18N.today, dateStart: 'Today', dateEnd: 'Today' },
                {text: SurveyI18N.yesterday, dateStart: 'Today-1', dateEnd: 'Today-1' },
                {text: SurveyI18N.last_7_days, dateStart: 'Today-7', dateEnd: 'Today' },
                {text: SurveyI18N.last_30_days,dateStart: 'Today-30', dateEnd: 'Today'},
                {text: SurveyI18N.last_90_days,dateStart: 'Today-90',  dateEnd: 'Today'}
            ],
            presets: {
                dateRange: SurveyI18N.custom_daterange
            },
            dateFormat: getDateFormat('datepicker_escaped'),
            closeOnSelect: true,
            presetRangesCallback: true,
            onClose: function(){
                var timestamp = SurveyDateRange.convertDateToTimestamp(jQuery("#survey_date_range").val());
                var dateRange = SurveyDateRange.convertTimestampToDate(timestamp);
                jQuery("#survey_date_range_link").text(dateRange);
                SurveyState.filterChanged = true;
                SurveyState.fetch();
                SurveyDateRange.close();
            }
        }); 
        jQuery("#survey_date_range").bind('keypress keyup keydown', function(ev) {
        ev.preventDefault();
        return false;
        });
    },
    open:function(){
        jQuery("#survey_date_link_container").hide();
        jQuery("#survey_date_text_container").show();
        jQuery("#survey_date_range").trigger('click');
    },
    close:function(){
       jQuery("#survey_date_text_container").hide();
       jQuery("#survey_date_link_container").show();
    },
    convertDateToTimestamp:function(date){
        var dateArray = date.split("-");
        var d_from = new Date(dateArray[0]);
        var fromTimestamp = (("0" + (d_from.getDate())).slice(-2))  + "" + (("0" + (d_from.getMonth()+1)).slice(-2)) + "" +
                            (d_from.getYear()+1900);
        
        var timestamp = fromTimestamp;
        if(dateArray[1]){
            var d_to = new Date(dateArray[1]);
            var toTimestamp   = (("0" + (d_to.getDate())).slice(-2)) + "" + (("0" + (d_to.getMonth()+1)).slice(-2)) + "" +(d_to.getYear()+1900);
            timestamp += "-" + toTimestamp;
        }
        return timestamp;
    },
    convertTimestampToDate: function(timestamp){
        var formatDate = function(date){
            return date.substring(0,2)+ " " + SurveyI18N.month_names[(parseInt(date.substring(2,4)))]+", "+(date.substring(4,8));
        }
        var dateArray = timestamp.split("-");        
        fromDate  = formatDate(dateArray[0]);
        var dateRange = fromDate ;
        if(dateArray[1]){
            toDate    = formatDate(dateArray[1]);
            dateRange += "-" + toDate;
        }
        return dateRange;
    },
    convertDiffToTimestamp: function(date_diff){
        var date_range;
        var endDate = new Date();
        var startDate  = new Date(new Date().setDate(endDate.getDate()-date_diff));
        endDate = endDate.toLocaleDateString();
        startDate = startDate.toLocaleDateString();
        if(date_diff == 0){
            date_range = endDate;
        }
        else if(date_diff == 1){
            date_range = startDate;
        }
        else{
            date_range = startDate + "-" + endDate;
        }
        return  SurveyDateRange.convertDateToTimestamp(date_range);
    },
    convertTimestampToDateEn: function(timestamp){
        var formatDate = function(date){
            return date.substring(0,2)+ " " + SurveyDateRange.month_names[(parseInt(date.substring(2,4))-1)]+", "+(date.substring(4,8));
        }
         var dateArray = timestamp.split("-");        
        fromDate  = formatDate(dateArray[0]);
        var dateRange = fromDate ;
        if(dateArray[1]){
            toDate    = formatDate(dateArray[1]);
            dateRange += "-" + toDate;
        }
        return dateRange;
    }
}

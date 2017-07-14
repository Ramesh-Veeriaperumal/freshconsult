/**
 * Tests if the qna json is valid or not
 * @param {*param} lang 
 * 
 * Version 1.0
 */
Qna_test = (function($) {

    const constants = {
			api : '/',
			filter_widgets : {
				"1" : "autocomplete_es", // include endpoint in json
				"2" : "autocomplete", // include key of object in json
				"3" : "checkbox"
			},
			events_namespace : '.qna',
	};

    function print(errors) {
        var any_error = false;
        console.group('QNA Debugger')
            jQuery.each(_.keys(errors),function(i,type){
                    if(errors[type].length != 0) {
                        console.group(type);
                        any_error = true;
                    }
                    jQuery.each(errors[type],function(x,row){
                        console.log(row)
                    });
                    if(errors[type].length != 0) {
                        console.groupEnd();
                    }
            });
        if(!any_error){
            console.log('%c JSON looks good to me..!','font-size: 12px;background: #006063; color: #fff')
        }
        console.groupEnd();
    }

    function validate(json,level,child_obj,errors,no_of_levels,nested_key) {
        
        var rows = child_obj['options'];
        if(!child_obj.hasOwnProperty("req_key")) {
            var _err = {
                message : 'req_key is not defined',
                info : 'Ajax request cannot send data for this option',
                level : level,
                child_key : nested_key,
            }
            errors['other_errors'].push(_err);
        }
        if(child_obj["searchable"] == "true" && !child_obj.hasOwnProperty('placeholder')) {
            var _err = {
                message : 'placeholder is not defined',
                info : 'Search bar will show undefined',
                level : level,
                child_key : nested_key,
            }
            errors['other_errors'].push(_err);
        }

          if(child_obj.hasOwnProperty("filter")) {
                var req = [ 'back_breadcrumb' ,'back_breadcrumb_in'];
                jQuery.each(req,function(indx,attr){
                    if(!child_obj.hasOwnProperty(attr)){
                        var _err = {
                            message : attr + ' is not defined',
                            info : 'For filter to navigate properly,' + attr + ' is required',
                            level : level,
                            child_key : nested_key,
                            option : i + ""
                        }
                        errors['other_errors'].push(_err);
                    }
                });
            }


        //Option checking
        jQuery.each(rows,function(i,row) {
            //check for empty values
            var row_props = _.keys(row);
            jQuery.each(row_props,function(l,key){
                if(is_empty(row[key])) {
                    var _err = {
                        message : key + ' is empty',
                        level : level,
                        child_key : nested_key,
                        option : i + ""
                    }
                    errors['value_errors'].push(_err);
                }
            });

            if(row.hasOwnProperty('search_breadcrumb_in')) {
                var target_level = row['search_breadcrumb_in'];
                if(target_level > no_of_levels -1) {
                    var _err = {
                        message : 'search_breadcrumb_in is invalid, Level not found',
                        level : level,
                        child_key : nested_key,
                        option : i + ""
                    }
                    errors['other_errors'].push(_err);
                } else {
                    var target = json[target_level];
                    var breadcrumb = row['breadcrumb'];
                    if(target[breadcrumb] == undefined) {
                        var _err = {
                            message : 'breadcrum is invalid',
                            info : "There is no key with value " + breadcrumb + " in level " + target_level,
                            level : level,
                            child_key : nested_key,
                            option : i + ""
                        }
                        errors['other_errors'].push(_err);
                    }
                }
            }

            if(child_obj.hasOwnProperty("filter")) {
                var req = [ 'widget_type'];
                jQuery.each(req,function(indx,attr){
                    if(!row.hasOwnProperty(attr)){
                        var _err = {
                            message : attr + ' is not defined',
                            info : 'For filter to work properly,' + attr + ' is required',
                            level : level,
                            child_key : nested_key,
                            option : i + ""
                        }
                        errors['other_errors'].push(_err);
                    }else{
                        if(attr == 'widget') {
                            //check for validity of widget
                            var available_widget_types = _.keys(constants.filter_widgets);
                            var widget_val = row['widget'];
                            if(!is_empty(widget_val)) {

                                if(jQuery.inArray(widget_val,available_widget_types) < 0){
                                    var _err = {
                                        message : 'Unknown widget type.check the constants in qna_util.js',
                                        info : 'Only select2 and checkbox are supported as of now.Implementing new filter ? Read the doc',
                                        level : level,
                                        child_key : nested_key,
                                        option : i + ""
                                    }
                                    errors['other_errors'].push(_err);
                                }
                            }
                        } 
                    }
                });
            }

            if(row.hasOwnProperty("feature_check")) {
                var feature = row['feature_check'];

                if(!HelpdeskReports.features.hasOwnProperty(feature)){
                    var _err = {
                        message : 'feature check is invalid',
                        info : 'HelpdeskReports.features namespace doesn\'t have ' + feature + " attribute",
                        level : level,
                        child_key : nested_key,
                        option : i + ""
                    }
                    errors['other_errors'].push(_err);
                }
            }
        });
    }

    function is_empty(val){
        return val == undefined || val == '';
    }

    
    return function testQna(lang) {
    
        var json = QLANG[lang];
        var no_of_levels = _.keys(json).length;
        var errors = {
            value_errors : [],
            other_errors : []
        };

        for (var prop in json) {
            if (!json.hasOwnProperty(prop)) {
                continue;
            }

            var keys = _.keys(json[prop]);
            jQuery.each(keys,function(i,nested_key){
                validate(json,prop,json[prop][nested_key],errors,no_of_levels,nested_key);
            });
        }
        print(errors);
    }

})(jQuery);

/**
 * This is a wrapper function for handling Ticket list sidebar data population
 *
 * TODO 1: This should be merged to ticket list Fjax configuration, once jQuery migration is released
 *
 * TODO 2: Make description clear for each method
 */

var TicketListSidebar = (function(){

  var URL = "/helpdesk/tickets/filter_conditions",
      DEFAULT_KEY = "new_and_my_open",
      COOKIE_FILTER_NAME = 'filter_name',
      parentWrapper = "ticket-leftFilter",
      childWrapper =  "filter_item";

  function getParams(fieldMap, callback){
    var queryString = _getUrlQueryString(),
        isDataRequired = jQuery.isEmptyObject(queryString.qsObj),
        params = {};
    params['fieldMap'] = fieldMap;
    if(isDataRequired){
      params['isAjax'] = true;
      params['url'] = URL;
      params['parentWrapper'] = parentWrapper;
      params['childWrapper'] = childWrapper;
      params['defaultKey'] = _getDefaultParams();
    }else{
      params['data'] = queryString.qsObj;
      params['isAjax'] = queryString.ajax_flag;
      if(params['isAjax']){
        params['url'] = URL;
        params['defaultKey'] = _getDefaultParams();
      }
    }
    if(typeof callback === 'function'){
        callback(params);
    }
  }

  return {
    getParams: getParams
  }

  // PRIVATE

  function _getDefaultParams(){
    var getSavedView = getCookie(COOKIE_FILTER_NAME);
    return getSavedView ? getSavedView : DEFAULT_KEY;
  }

  /**
  * returns query string as an object;
  */

  function _getUrlQueryString(){
      var dashboard_options = { 'ajax_flag' : false },
          url = window.location.search.substr(1).split('&');
      if (url == "") return {};
      var qsObj = {};
      for (var i = 0; i < url.length; ++i){
        var p = url[i].split('=');
        // To handle the case of hitting tickets list page from dashboard for top 10 customers/top 10 agents
        if(p[0] == "requester" || p[0] == "agent"){
          dashboard_options['ajax_flag'] = true;
        }
        if (p.length != 2) continue;
        qsObj[p[0]] = decodeURIComponent(p[1].replace(/\+/g, " "));
      }
      dashboard_options['qsObj'] = qsObj;
      return dashboard_options; // Return Query string Object 
  }

}());

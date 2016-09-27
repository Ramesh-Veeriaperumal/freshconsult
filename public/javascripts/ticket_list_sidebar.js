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
    var isDataRequired = _isDataRequired(), params = {};
    params['fieldMap'] = fieldMap;
    if(isDataRequired){
      params['isAjax'] = true;
      params['url'] = URL;
      params['parentWrapper'] = parentWrapper;
      params['childWrapper'] = childWrapper;
      params['defaultKey'] = _getDefaultParams();
    }else{
      params['isAjax'] = false;
      params['data'] = _getUrlQueryString();
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
  * return true if query param is an empty object;
  */

  function _isDataRequired(){
    var queryString = _getUrlQueryString();
    return jQuery.isEmptyObject(queryString);
  }

  /**
  * returns query string as an object;
  */

  function _getUrlQueryString(){
      var url = window.location.search.substr(1).split('&');
      if (url == "") return {};
      var qsObj = {};
      for (var i = 0; i < url.length; ++i){
        var p = url[i].split('=');
        if (p.length != 2) continue;
        qsObj[p[0]] = decodeURIComponent(p[1].replace(/\+/g, " "));
      }
      return qsObj; // Query string Object
  }

}());

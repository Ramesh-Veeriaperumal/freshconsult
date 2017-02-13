
/**
 * Get profile image
 * 
 * Get image URL by id using - ProfileImage.imageById(id)
 * 							   id - Integer
 * 
 */

var ProfileImage = ProfileImage || (function(){

	var profileimg = {};
	profileimg.imageArray = [];
	profileimg.fetch = function(cb){
		_getImage().success(function(data){
			if (Array.isArray(data)) {
				profileimg.imageArray = data;
			} else {
				profileimg.error = data;
			}
			if(typeof cb === "function") cb(data);
		}).error(function(){
			
		})
	}

	profileimg.imageById = function(userid){
		var index = _getIndex(userid);
		return index !== -1 ? profileimg.imageArray[parseInt(index)] : false;
	}

	return profileimg;

	function _getIndex(userid){
		return _keys().indexOf(userid);
	}

	function _keys(){
		return profileimg.imageArray.pluck('user_id')
	}

	function _getImage(){
		return jQuery.ajax({
			url: "/admin/roles/profile_image",
			method: "GET",
			dataType: "JSON"
		})
	}

})();
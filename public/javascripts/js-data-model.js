/**
 * Create Factory for DataStore
 * @param {[String]} key [Unique key for the Object. By default it will be 'id' ]
 */
function DataFactory(key) {
	this.key = key || "id";
	this.store = {};
	this.currentData = [];
	this.cachedIndex = {};
	this.set = function(name, data){
		this.store[name] = data;
	}
	this.get = function(name){
		this.cachedIndex = {};
		this.currentObj = name;
		this._updateData(this.store[name]);
		return this;
	}
	this._updateData = function(data){
		this.currentData = data;
	}
}
/**
 * 
 * Utility functions for DataFactory
 *
 */
var DataModel = {
	getCachedIndex: function(){
		this.cachedIndex[this.key] = this._pluck(this.key) || [];
		return this.cachedIndex
	},
	cacheIndex: function(id){
		this.cachedIndex[id] = this._pluck(id) || [];
	},
	size: function(){
		return this.currentData.length;
	},
	all: function(){
		return this.currentData.slice();
	},
	first: function(){
		return this.currentData[0];
	},
	last: function(){
		var length = this.size();
		return this.currentData[length-1];
	},
	find: function(id, key){
		if(this._getCachedKey().indexOf(key) === -1){
			this.cacheIndex(key);
		}
		var index = this._getIndex(id, key);
		if(index === -1){return false;}
		return this.currentData[index];
	},
	findById: function(id){
		var index = this._getIndex(id);
		if(index === -1){return false;}
		return this.currentData[index];
	},
	findMany: function(){
		var args = Array.prototype.slice.call(arguments);
		if(args.length === 1){
			this.find(args[0]);
			return;
		}
		var keys = this._keys();
		var intersectArray = [];
		var uniqueArg = args.uniq();
		if(args.length === 0){return this.all();}
		uniqueArg.map(function(val, index){
			if(keys.indexOf(val) !== -1 && intersectArray.indexOf(val) !== 1){
				intersectArray.push(this.currentData[keys.indexOf(val)]);
			}
		}.bind(this));
		return intersectArray;
	},
	_getIndex: function(id, sec_key){
		if(this._getCachedKey().indexOf(this.key) === -1){
			this.getCachedIndex();  //Call cacing for the first time;
		}
		keys = sec_key ? this.cachedIndex[sec_key] : this.cachedIndex[this.key];
		return keys.indexOf(id);
	},
	_getCachedKey: function(){
		return Object.keys(this.cachedIndex);
	},
	_keys: function(){
		return this._pluck();
	},
	_pluck: function(key){
		return this.currentData.map(function(val){
			return val[key || this.key] ? val[key || this.key] : null;
		}.bind(this));
	}
}

DataFactory.prototype = DataModel;

/**
 * Creating instance for DataFactory and setting Unique key as 'id' (By default).
 */
var DataStore = new DataFactory('id');

function createDataStore(data){
  for (var key in data) {
    if(data.hasOwnProperty(key)){
      DataStore.set(key, data[key]);
    }
  };
  return DataStore;
}

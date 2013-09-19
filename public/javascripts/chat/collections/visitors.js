define([
	'models/visitors'
], 
function(Visitor){
	var Visitors = Backbone.Collection.extend({
    	model:Visitor,
		url:'javascript:void();',
		addNew:function(visitors){
			visitor = this.create(visitors);
			this.add(visitor,{merge: true});
			return visitor;
		},
		getVisitors:function(type){
			var filter = this.filter(function(visitor){return visitor.get(type) != undefined;});
			return filter;
		},
		count:function(type){
			var filter = this.getVisitors(type);
			return filter.length;
		},
		deleteVisitor:function(id){
			var visitor = this.get(id);
			this.remove(visitor);
		},
		modify:function(data){
			var visitor = this.get(data.id);
			visitor.set({sclass:"chat-visitor", agent:data.agent, name:data.name});
			this.addNew(visitor);
		}
	});
	return Visitors;
});
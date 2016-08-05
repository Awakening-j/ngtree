_module = angular.module 'ngTree'
_module
	.directive 'ngTree', ->

		directive =
			restrict: 'AE'
			scope: 
				nodes: '='
			templateUrl: "ng_tree.html"
			link: (scope,element)->
				# set level and end for each node
				dataFormat = (node, level = 0, pAlert = 2)->
					# node[0].hasOwnProperty('level'): prevent execute $watch by _show or _collapse, if new node it will return false
					if node and node.length and !node[0].hasOwnProperty('level')
						for d,index in node
							# for better performance, do not filter in recursive template
							d.level = level
							d._collapse_stack = true
							d._collapse = (d.isExternal and d.taskId) or (pAlert isnt 0 and d.alert is 0 and d.list and d.list.length)
							d._collapse_init = true
							if d.list and d.list.length
								arguments.callee(d.list,level+1, d.alert)
							else
								d.end = true

				# watch once to init listData
				scope.$watch 'nodes', (n,o)->
					if n
						console.log('dataFormat')
						dataFormat(scope.nodes)
				, true


				# toggle collapse when click circle
				scope.collapse = (data)->
					if data.isExternal and data.taskId
						if data._collapse and !data.list.length
							data._loading = true
							transflowService.getTransDetail(data.taskId, data.transactionId).then(
									(response)->
										data.end = false
										dataFormat(response.detail, data.level+1)
										data.list = response.detail
										# bugfix: sometimes tree level not expand entirely
										$timeout (->
										), 100
								,
									(err)->
										console.log 'error'
								).then(
									()->
										data._loading = false
										data._collapse = false
								)
						else
							data._collapse = !data._collapse
					else if !data.end
						data._collapse = !data._collapse

					#collapse backtrace
					if data._collapse
						data._collapse_stack = true
						
		return directive
			
_module.run ["$templateCache", ($templateCache)->
		$templateCache.put "ng_tree.html", """
			<div class="ng-tree-wrap">
				<ul class="list-unstyled">
					<li class="tree-level tree-level-{{node.level}}" 
						 ng-class="{'tree-level-last': $index == nodes.length-1, 'end': node.end}" 
						 ng-repeat="node in ::nodes" ng-include="'tree_node.html'">
					</li>
				</ul>
			</div>
		"""
		
		$templateCache.put "tree_node.html", """
			<div ng-include="'tree_branch.html'" class="tree-branch tree-branch-{{branchLevel}}" 
					 ng-class="{'tree-branch-last': node.level == branchLevel, 'transflow-collapse': node._collapse}" 
					 ng-init="branchLevel=0">
			</div>
			 <ul ng-hide="node._collapse">
					 <li class="tree-level tree-level-{{::node.level}}" node-length="{{::node.list.length}}" ng-class="{'tree-level-last': $index == deep-1, 'end': node.end}" ng-repeat="node in ::node.list" ng-include="'tree_node.html'" ng-init="deep = $parent.node.list.length"></li>
			 </ul>
		"""
		
		$templateCache.put "tree_branch.html", """
			<div class="node-entry" ng-if="::node.level == branchLevel">
				<span class='icon-circle text-alert-{{::node.alert}}' ng-click="collapse(node)" ng-class="{'circle-fill': node._collapse}"></span>
				<div class="node-item">
					<span class='ext' ng-show="::node.isExternal">{{::node.appName}}</span>
					{{::node.startTime}}<span class="loading-box"><i ng-show="node._loading" class="iconfont loading-icon">&#xe675;</i></span><br/>
					<span class="text-grey pointer trans-name" ng-click="node._collapse_stack = !node._collapse_stack">{{::node.name}}</span><i ng-show="node.sql" class="iconfont icon-sql" tooltip="{{::node.sql}}">&#xe6e2;</i>
					<div collapse="node._collapse_stack" class="backtrace-collapse">
						<div class="do-not-remove-this-div">
							<div class="do-not-remove-this-div">
								<div ng-show="!node.backtrace || node.backtrace.length == 0">暂无堆栈信息</div>
								<div ng-show="node.backtrace && node.backtrace.length">堆栈信息:</div>
								<div ng-repeat="t in ::node.backtrace">{{::t}}</div>
							</div>
						</div>
					</div>
				</div>
			</div>
			<div ng-include="'tree_branch.html'" class="tree-branch tree-branch-{{branchLevel}}" ng-class="{'tree-branch-last': node.level == branchLevel, 'transflow-collapse': node._collapse}" ng-if="node.level > branchLevel" ng-init="branchLevel = $parent.branchLevel + 1"></div>
		"""
]
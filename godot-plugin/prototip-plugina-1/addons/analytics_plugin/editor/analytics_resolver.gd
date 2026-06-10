@tool
extends RefCounted
## Поиск autoload Analytics в редакторе и при запуске игры (F5).

static func resolve(from_node: Node) -> Node:
	if from_node == null:
		return null

	if from_node.has_meta("get_analytics"):
		var cb: Callable = from_node.get_meta("get_analytics")
		if cb.is_valid():
			var via_callable: Variant = cb.call()
			if via_callable is Node and is_instance_valid(via_callable):
				return via_callable

	var trees: Array[SceneTree] = []

	var local_tree: SceneTree = from_node.get_tree()
	if local_tree:
		trees.append(local_tree)

	var plugin: Variant = from_node.get_meta("editor_plugin", null)
	if plugin is EditorPlugin:
		var editor_iface: EditorInterface = plugin.get_editor_interface()
		if editor_iface:
			var base: Control = editor_iface.get_base_control()
			if base:
				var editor_tree: SceneTree = base.get_tree()
				if editor_tree and editor_tree != local_tree:
					trees.append(editor_tree)

	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var main_tree: SceneTree = loop
		if not trees.has(main_tree):
			trees.append(main_tree)

	for st in trees:
		var node: Node = st.root.get_node_or_null("Analytics")
		if node:
			return node

	return null

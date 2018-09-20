package hide.comp.cdb;

class ScriptTable extends SubTable {

	var script : hide.comp.ScriptEditor;

	override function makeSubSheet():cdb.Sheet {
		var sheet = cell.table.sheet;
		var c = cell.column;
		var index = cell.line.index;
		var key = sheet.getPath() + "@" + c.name + ":" + index;
		this.lines = [];
		return new cdb.Sheet(editor.base, {
			columns : [c],
			props : {},
			name : key,
			lines : [cell.line.obj],
			separators: [],
		}, key, { sheet : sheet, column : cell.columnIndex, line : index });
	}

	override function refresh() {
		var first = script == null;
		element.html("<div class='cdb-script'></div>");
		var checker = new ScriptEditor.ScriptChecker(editor.config,"cdb."+cell.table.sheet.name+"."+cell.column.name,[ "cdb."+cell.table.sheet.name => cell.line.obj ]);
		script = new ScriptEditor(cell.value, checker, element.find("div"));
		script.onSave = function() @:privateAccess cell.setValue(script.script);
		script.onClose = function() { close(); cell.select(); }
		lines = [new Line(this,[],0,script.element)];
		if( first ) script.focus();
	}

}


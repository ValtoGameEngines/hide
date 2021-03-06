package hide.comp.cdb;

typedef DataProps = {
	var file : String;
	var path : String;
	var origin : String;
}

class DataFiles {

	static var changed : Bool;
	static var skip : Int = 0;
	static var watching : Map<String, Bool> = new Map();
	static var base(get,never) : cdb.Database;

	static function get_base() return Ide.inst.database;

	public static function load() {
		for( sheet in base.sheets )
			if( sheet.props.dataFiles != null && sheet.lines == null )
				loadSheet(sheet);
	}

	static function onFileChanged() {
		if( skip > 0 ) {
			skip--;
			return;
		}
		changed = true;
		haxe.Timer.delay(function() {
			if( !changed ) return;
			changed = false;
			for( s in base.sheets )
				if( s.props.dataFiles != null ) @:privateAccess {
					s.sheet.lines = null;
					s.sheet.linesData = null;
				}
			load();
			Editor.refreshAll(true);
		},0);
	}

	static function loadSheet( sheet : cdb.Sheet ) {
		var ide = Ide.inst;
		var lines : Array<Dynamic> = [];
		var linesData : Array<DataProps> = [];
		var separators = [];
		var separatorTitles = [];
		@:privateAccess {
			sheet.sheet.lines = lines;
			sheet.sheet.linesData = linesData;
			sheet.sheet.separators = separators;
			sheet.props.separatorTitles = separatorTitles;
		}
		function loadFile( file : String ) {
			var needSep = true;
			var levelID = file.split("/").pop().split(".").shift();
			levelID = levelID.charAt(0).toUpperCase()+levelID.substr(1);
			function loadRec( p : hrt.prefab.Prefab ) {
				if( p.getCdbModel() == sheet ) {
					var dprops : DataProps = {
						file : file,
						path : p.getAbsPath(),
						origin : haxe.Json.stringify(p.props),
					};
					if( needSep ) {
						separators.push(lines.length);
						separatorTitles.push(file);
						needSep = false;
					}
					if( sheet.idCol != null && Reflect.field(p.props,sheet.idCol.name) == "" )
						Reflect.setField(p.props,sheet.idCol.name,levelID+"_"+p.name);
					linesData.push(dprops);
					lines.push(p.props);
				}
				for( p in p ) loadRec(p);
			}
			var p = ide.loadPrefab(file);
			loadRec(p);
			if( !watching.exists(file) ) {
				watching.set(file, true);
				ide.fileWatcher.register(file, onFileChanged);
			}
		}

		var path = sheet.props.dataFiles.split("/");
		function gatherRec( curPath : Array<String>, i : Int ) {
			var part = path[i++];
			if( part == null ) {
				var file = curPath.join("/");
				if( sys.FileSystem.exists(ide.getPath(file)) ) loadFile(file);
				return;
			}
			if( part.indexOf("*") < 0 ) {
				curPath.push(part);
				gatherRec(curPath,i);
				curPath.pop();
			} else {
				var path = curPath.join("/");
				var dir = ide.getPath(path);
				if( !sys.FileSystem.isDirectory(dir) )
					return;
				if( !watching.exists(path) ) {
					watching.set(path, true);
					ide.fileWatcher.register(path, onFileChanged, true);
				}
				var reg = new EReg("^"+part.split(".").join("\\.").split("*").join(".*")+"$","");
				for( f in sys.FileSystem.readDirectory(dir) ) {
					if( !reg.match(f) ) continue;
					curPath.push(f);
					gatherRec(curPath,i);
					curPath.pop();
				}
			}
		}
		gatherRec([],0);
	}

	public static function save( ?onSaveBase, ?force ) {
		var ide = Ide.inst;
		var temp = [];
		var titles = [];
		var prefabs = new Map();
		for( s in base.sheets )
			if( s.props.dataFiles != null ) {
				var sheet = @:privateAccess s.sheet;
				var ldata = sheet.linesData;
				for( i in 0...s.lines.length ) {
					var o = s.lines[i];
					var p : DataProps = sheet.linesData[i];
					var str = haxe.Json.stringify(o);
					if( str != p.origin || force ) {
						p.origin = str;
						var pf : hrt.prefab.Prefab = prefabs.get(p.file);
						if( pf == null ) {
							pf = ide.loadPrefab(p.file);
							prefabs.set(p.file, pf);
						}
						var inst : hrt.prefab.Prefab = pf.getPrefabByPath(p.path);
						if( inst == null || inst.getCdbModel() != s )
							ide.error("Can't save prefab data "+p.path);
						else
							inst.props = o;
					}
				}
				temp.push(Reflect.copy(sheet));
				titles.push(sheet.props.separatorTitles);
				Reflect.deleteField(sheet,"lines");
				Reflect.deleteField(sheet,"linesData");
				Reflect.deleteField(sheet.props,"separatorTitles");
				sheet.separators = [];
			}
		for( file => pf in prefabs ) {
			skip++;
			sys.io.File.saveContent(ide.getPath(file), ide.toJSON(pf.saveData()));
		}
		if( onSaveBase != null )
			onSaveBase();
		for( s in base.sheets ) {
			if( s.props.dataFiles != null ) {
				var d = temp.shift();
				var sheet = @:privateAccess s.sheet;
				sheet.lines = d.lines;
				sheet.linesData = d.linesData;
				sheet.separators = d.separators;
				sheet.props.separatorTitles = titles.shift();
			}
		}
	}

}

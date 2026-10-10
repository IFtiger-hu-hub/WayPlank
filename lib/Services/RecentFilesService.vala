//
//  Copyright (C) 2026 Sergio Melas & DeepMind Antigravity
//
//  This file is part of Wayplank.
//
//  Wayplank is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Wayplank is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Plank
{
	public class RecentFileInfo : GLib.Object
	{
		public string path { get; set; default = ""; }
		public string title { get; set; default = ""; }
		public string display_path { get; set; default = ""; }
		public bool is_dir { get; set; default = false; }
		public string mimetype { get; set; default = ""; }
		public int64 time { get; set; default = 0LL; }
	}

	public class RecentFilesService : GLib.Object
	{
		private static RecentFilesService? instance = null;

		public static RecentFilesService get_default ()
		{
			if (instance == null)
				instance = new RecentFilesService ();
			return instance;
		}

		private Gee.HashMap<string, Gee.ArrayList<RecentFileInfo>> cache = new Gee.HashMap<string, Gee.ArrayList<RecentFileInfo>> ();
		private int64 last_mtime = 0LL;

		construct
		{
			load_cache ();
		}

		public void refresh ()
		{
			load_cache ();
		}

		string? get_cache_path ()
		{
			var user_cache = Environment.get_user_cache_dir ();
			var p1 = Path.build_filename (user_cache, "wayplank", "recent_files_cache.json");
			if (FileUtils.test (p1, FileTest.EXISTS))
				return p1;
			var p2 = Path.build_filename (user_cache, "noctalia-qs", "recent_files_cache.json");
			if (FileUtils.test (p2, FileTest.EXISTS))
				return p2;
			return p1;
		}

		void load_cache ()
		{
			var cache_path = get_cache_path ();
			if (cache_path == null) {
				trigger_update_script ();
				return;
			}
			var file = File.new_for_path (cache_path);
			if (!file.query_exists ()) {
				trigger_update_script ();
				return;
			}

			try {
				var info = file.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
				var mtime = (int64) info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
				if (mtime == last_mtime && cache.size > 0)
					return;

				var parser = new Json.Parser ();
				parser.load_from_file (cache_path);
				var root = parser.get_root ();
				if (root == null || root.is_null ())
					return;

				var obj = root.get_object ();
				if (obj == null)
					return;

				Json.Object? data_obj = null;
				if (obj.has_member ("data"))
					data_obj = obj.get_object_member ("data");
				else
					data_obj = obj;

				if (data_obj == null)
					return;

				cache.clear ();
				foreach (var key in data_obj.get_members ()) {
					var arr_node = data_obj.get_member (key);
					if (arr_node == null || arr_node.get_node_type () != Json.NodeType.ARRAY)
						continue;

					var arr = arr_node.get_array ();
					var list = new Gee.ArrayList<RecentFileInfo> ();
					for (uint i = 0; i < arr.get_length (); i++) {
						var item_node = arr.get_element (i);
						if (item_node == null || item_node.get_node_type () != Json.NodeType.OBJECT)
							continue;
						var item_obj = item_node.get_object ();
						var item = new RecentFileInfo ();
						if (item_obj.has_member ("path"))
							item.path = item_obj.get_string_member ("path");
						if (item_obj.has_member ("title"))
							item.title = item_obj.get_string_member ("title");
						if (item_obj.has_member ("displayPath"))
							item.display_path = item_obj.get_string_member ("displayPath");
						if (item_obj.has_member ("isDir"))
							item.is_dir = item_obj.get_boolean_member ("isDir");
						if (item_obj.has_member ("mimetype"))
							item.mimetype = item_obj.get_string_member ("mimetype");
						if (item_obj.has_member ("time"))
							item.time = item_obj.get_int_member ("time");

						if (item.path.length > 0)
							list.add (item);
					}
					cache.set (key, list);
				}

				last_mtime = mtime;
			} catch (Error e) {
				Logger.notification ("RecentFilesService: Failed to parse cache: %s", e.message);
			}
		}

		void trigger_update_script ()
		{
			string? script_path = GLib.Environment.get_variable ("WAYPLANK_RECENT_FILES_SCRIPT");
			if (script_path == null || !FileUtils.test (script_path, FileTest.EXISTS)) {
				var home = Environment.get_home_dir ();
				var candidate1 = Path.build_filename (Environment.get_user_data_dir (), "wayplank", "scripts", "recent_files.py");
				var candidate2 = "/usr/share/wayplank/scripts/recent_files.py";
				var candidate3 = Path.build_filename (home, "Github", "kde-quickshell-dock", "recent_files.py");
				if (FileUtils.test (candidate1, FileTest.EXISTS))
					script_path = candidate1;
				else if (FileUtils.test (candidate2, FileTest.EXISTS))
					script_path = candidate2;
				else if (FileUtils.test (candidate3, FileTest.EXISTS))
					script_path = candidate3;
				else
					return;
			}

			try {
				string[] argv = { "python3", script_path };
				Pid pid;
				Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid);
				ChildWatch.add (pid, (p, status) => {
					Process.close_pid (p);
					load_cache ();
				});
			} catch (Error e) {
				Logger.notification ("RecentFilesService: Failed to spawn recent_files.py: %s", e.message);
			}
		}

		public Gee.ArrayList<string> get_aliases_for (string? app_id, string? launcher_uri, string? app_name)
		{
			var result = new Gee.ArrayList<string> ();
			var candidates = new Gee.ArrayList<string> ();

			if (app_id != null && app_id.length > 0)
				candidates.add (app_id);
			if (launcher_uri != null && launcher_uri.length > 0) {
				var bname = Path.get_basename (launcher_uri);
				candidates.add (bname);
			}
			if (app_name != null && app_name.length > 0)
				candidates.add (app_name);

			foreach (var c in candidates) {
				var s = c.strip ().down ();
				if (s.has_suffix (".desktop"))
					s = s.substring (0, s.length - 8);
				if (s.contains ("/")) {
					var parts = s.split ("/");
					s = parts[parts.length - 1];
				}

				if (!result.contains (s))
					result.add (s);

				if (s.has_prefix ("org.kde.")) {
					var sub = s.substring (8);
					if (!result.contains (sub))
						result.add (sub);
				}
				if (s.has_prefix ("com.")) {
					var parts = s.split (".");
					var last = parts[parts.length - 1];
					if (!result.contains (last))
						result.add (last);
				}
				if ("edge" in s) {
					if (!result.contains ("edge")) result.add ("edge");
					if (!result.contains ("microsoft-edge")) result.add ("microsoft-edge");
					if (!result.contains ("com.microsoft.edge")) result.add ("com.microsoft.edge");
				}
				if ("chrome" in s) {
					if (!result.contains ("chrome")) result.add ("chrome");
					if (!result.contains ("google-chrome")) result.add ("google-chrome");
				}
				if ("jetbrains-" in s) {
					var parts = s.split ("-");
					if (parts.length >= 2) {
						if (!result.contains (parts[1])) result.add (parts[1]);
					}
				}
				if ("okular" in s) {
					if (!result.contains ("okular")) result.add ("okular");
					if (!result.contains ("org.kde.okular")) result.add ("org.kde.okular");
				}
				if ("dolphin" in s) {
					if (!result.contains ("dolphin")) result.add ("dolphin");
					if (!result.contains ("org.kde.dolphin")) result.add ("org.kde.dolphin");
				}
				if ("kate" in s) {
					if (!result.contains ("kate")) result.add ("kate");
					if (!result.contains ("org.kde.kate")) result.add ("org.kde.kate");
				}
				if ("antigravity" in s) {
					if (!result.contains ("antigravity")) result.add ("antigravity");
					if (!result.contains ("antigravity-ide")) result.add ("antigravity-ide");
				}
			}

			return result;
		}

		public Gee.ArrayList<RecentFileInfo> get_recent_files (string? app_id, string? launcher_uri, string? app_name)
		{
			load_cache ();
			var aliases = get_aliases_for (app_id, launcher_uri, app_name);
			foreach (var alias in aliases) {
				if (cache.has_key (alias)) {
					var list = cache.get (alias);
					if (list != null && list.size > 0)
						return list;
				}
			}
			return new Gee.ArrayList<RecentFileInfo> ();
		}
	}
}

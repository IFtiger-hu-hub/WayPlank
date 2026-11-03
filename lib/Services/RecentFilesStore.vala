//
//  Copyright (C) 2026 Sergio Melas
//
//  This file is part of WayPlank.
//
//  WayPlank is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  WayPlank is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Plank
{
	/**
	 * Persists recently opened files per application launcher under
	 * ~/.config/kde-dockbar/recent-files.json
	 */
	public class RecentFilesStore : GLib.Object
	{
		const int MAX_PER_LAUNCHER = 8;
		const string STORE_FILENAME = "recent-files.json";

		static RecentFilesStore? instance = null;

		public static RecentFilesStore get_default ()
		{
			if (instance == null)
				instance = new RecentFilesStore ();
			return instance;
		}

		Gee.HashMap<string, Gee.ArrayList<string>> entries;
		bool loaded = false;

		construct
		{
			entries = new Gee.HashMap<string, Gee.ArrayList<string>> ();
		}

		public static string launcher_key (string launcher)
		{
			if (launcher == null || launcher == "")
				return "";

			string path = launcher;
			try {
				if (path.has_prefix ("file://"))
					path = Filename.from_uri (path);
			} catch (Error e) {
				var f = File.new_for_uri (launcher);
				path = f.get_path () ?? launcher;
			}

			var basename = Path.get_basename (path);
			if (basename.has_suffix (".desktop"))
				return basename;
			return path;
		}

		void ensure_loaded ()
		{
			if (loaded)
				return;
			loaded = true;
			load ();
		}

		File? store_file ()
		{
			if (Paths.AppConfigFolder == null)
				return null;
			Paths.ensure_directory_exists (Paths.AppConfigFolder);
			return Paths.AppConfigFolder.get_child (STORE_FILENAME);
		}

		void load ()
		{
			entries.clear ();
			var file = store_file ();
			if (file == null || !file.query_exists ())
				return;

			try {
				uint8[] data;
				string etag;
				file.load_contents (null, out data, out etag);
				var parser = new Json.Parser ();
				parser.load_from_data ((string) data, -1);
				var root = parser.get_root ();
				if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
					return;

				var obj = root.get_object ();
				foreach (var key in obj.get_members ()) {
					var node = obj.get_member (key);
					if (node == null || node.get_node_type () != Json.NodeType.ARRAY)
						continue;
					var list = new Gee.ArrayList<string> ();
					foreach (var child in node.get_array ().get_elements ()) {
						if (child.get_node_type () != Json.NodeType.VALUE)
							continue;
						var uri = child.get_string ();
						if (uri != null && uri != "")
							list.add (uri);
					}
					entries.set (key, list);
				}
			} catch (Error e) {
				warning ("RecentFilesStore: failed to load (%s)", e.message);
			}
		}

		void save ()
		{
			var file = store_file ();
			if (file == null)
				return;

			try {
				var builder = new Json.Builder ();
				builder.begin_object ();
				foreach (var key in entries.keys) {
					builder.set_member_name (key);
					builder.begin_array ();
					foreach (var uri in entries.get (key))
						builder.add_string_value (uri);
					builder.end_array ();
				}
				builder.end_object ();

				var generator = new Json.Generator ();
				generator.set_root (builder.get_root ());
				generator.pretty = true;
				generator.indent = 2;
				generator.to_file (file.get_path ());
			} catch (Error e) {
				warning ("RecentFilesStore: failed to save (%s)", e.message);
			}
		}

		static string? normalize_to_uri (string input)
		{
			if (input == null || input == "")
				return null;
			if (input.has_prefix ("http://") || input.has_prefix ("https://")
				|| input.has_prefix ("ftp://") || input.has_prefix ("file://"))
				return input;
			if (input.has_prefix ("/"))
				return File.new_for_path (input).get_uri ();
			return null;
		}

		static bool uri_exists (string uri)
		{
			if (uri.has_prefix ("http://") || uri.has_prefix ("https://") || uri.has_prefix ("ftp://"))
				return true;
			var f = File.new_for_uri (uri);
			return f.query_exists ();
		}

		/**
		 * Record one or more URIs opened with the given launcher.
		 */
		public void record (string launcher, string[] uris)
		{
			ensure_loaded ();
			var key = launcher_key (launcher);
			if (key == "" || uris == null || uris.length == 0)
				return;

			Gee.ArrayList<string> list;
			if (entries.has_key (key))
				list = entries.get (key);
			else {
				list = new Gee.ArrayList<string> ();
				entries.set (key, list);
			}

			bool changed = false;
			for (int i = uris.length - 1; i >= 0; i--) {
				var uri = normalize_to_uri (uris[i]);
				if (uri == null)
					continue;
				// Skip remote-only / transient schemes that are not useful as "recent files"
				if (uri.has_prefix ("http://") || uri.has_prefix ("https://") || uri.has_prefix ("ftp://"))
					continue;
				list.remove (uri);
				list.insert (0, uri);
				changed = true;
			}

			while (list.size > MAX_PER_LAUNCHER)
				list.remove_at (list.size - 1);

			if (changed)
				save ();
		}

		/**
		 * Return existing recent file URIs for launcher (newest first), pruned,
		 * merging Dock drag-and-drop history with IDE/application & system recent files.
		 */
		public Gee.ArrayList<string> get_recent (string launcher)
		{
			ensure_loaded ();
			var result = new Gee.ArrayList<string> ();
			var seen = new Gee.HashSet<string> ();
			var key = launcher_key (launcher);
			if (key == "")
				return result;

			if (entries.has_key (key)) {
				var list = entries.get (key);
				var kept = new Gee.ArrayList<string> ();
				bool pruned = false;
				foreach (var uri in list) {
					if (!uri_exists (uri)) {
						pruned = true;
						continue;
					}
					kept.add (uri);
					if (result.size < MAX_PER_LAUNCHER && !seen.contains (uri)) {
						result.add (uri);
						seen.add (uri);
					}
				}

				if (pruned || kept.size != list.size) {
					entries.set (key, kept);
					save ();
				}
			}

			if (result.size < MAX_PER_LAUNCHER)
				append_app_native_recent (launcher, key, result, seen);

			if (result.size < MAX_PER_LAUNCHER)
				append_system_recent (launcher, key, result, seen);

			return result;
		}

		static void add_recent_candidate (string raw_path_or_uri, Gee.ArrayList<string> result, Gee.HashSet<string> seen)
		{
			if (result.size >= MAX_PER_LAUNCHER)
				return;
			var uri = normalize_to_uri (raw_path_or_uri);
			if (uri == null || uri.has_prefix ("http://") || uri.has_prefix ("https://") || uri.has_prefix ("ftp://"))
				return;
			if (seen.contains (uri))
				return;
			if (!uri_exists (uri))
				return;
			seen.add (uri);
			result.add (uri);
		}

		static string extract_launcher_exec_binary (string launcher)
		{
			string path = launcher;
			try {
				if (path.has_prefix ("file://"))
					path = Filename.from_uri (path);
			} catch {
				var f = File.new_for_uri (launcher);
				path = f.get_path () ?? launcher;
			}
			try {
				var kf = new KeyFile ();
				if (System.load_keyfile_safe (kf, path, KeyFileFlags.NONE)) {
					if (kf.has_key (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_EXEC)) {
						string exec = kf.get_string (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_EXEC).strip ();
						if (exec.has_prefix ("\"")) {
							int end_q = exec.index_of ("\"", 1);
							if (end_q > 1)
								exec = exec.slice (1, end_q);
						} else {
							int sp = exec.index_of (" ");
							if (sp > 0)
								exec = exec.slice (0, sp);
						}
						return Path.get_basename (exec).down ();
					}
				}
			} catch {}
			return "";
		}

		void append_app_native_recent (string launcher, string key, Gee.ArrayList<string> result, Gee.HashSet<string> seen)
		{
			string lower_key = key.down ();
			string exec_bin = extract_launcher_exec_binary (launcher);
			string config_dir = Environment.get_user_config_dir ();
			string home_dir = Environment.get_home_dir ();

			// 1. OpenIDEA (~/.config/ai.l0ng.openidea/recent.json)
			if (lower_key.contains ("openidea") || exec_bin == "openidea") {
				string openidea_recent = Path.build_filename (config_dir, "ai.l0ng.openidea", "recent.json");
				if (FileUtils.test (openidea_recent, FileTest.EXISTS)) {
					try {
						var parser = new Json.Parser ();
						parser.load_from_file (openidea_recent);
						var root = parser.get_root ();
						if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
							foreach (var elem in root.get_array ().get_elements ()) {
								if (elem.get_node_type () != Json.NodeType.OBJECT)
									continue;
								var obj = elem.get_object ();
								if (obj.has_member ("path")) {
									var p = obj.get_string_member ("path");
									if (p != null && p != "")
										add_recent_candidate (p, result, seen);
								}
							}
						}
					} catch {}
				}
				return;
			}

			// 2. VS Code / Antigravity IDE / Cursor / Windsurf / VSCodium
			string[]? vscode_dirs = null;
			if (lower_key.contains ("antigravity") || exec_bin.contains ("antigravity")) {
				vscode_dirs = { "Antigravity IDE", "Antigravity" };
			} else if (lower_key.contains ("cursor") || exec_bin == "cursor") {
				vscode_dirs = { "Cursor" };
			} else if (lower_key.contains ("windsurf") || exec_bin == "windsurf") {
				vscode_dirs = { "Windsurf" };
			} else if (lower_key.contains ("codium") || exec_bin == "codium") {
				vscode_dirs = { "VSCodium" };
			} else if (lower_key == "code.desktop" || lower_key == "visual-studio-code.desktop" || exec_bin == "code") {
				vscode_dirs = { "Code" };
			}

			if (vscode_dirs != null) {
				foreach (var dir_name in vscode_dirs) {
					string storage_path = Path.build_filename (config_dir, dir_name, "User", "globalStorage", "storage.json");
					if (!FileUtils.test (storage_path, FileTest.EXISTS))
						continue;
					try {
						var parser = new Json.Parser ();
						parser.load_from_file (storage_path);
						var root = parser.get_root ();
						if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
							continue;
						var root_obj = root.get_object ();

						if (root_obj.has_member ("backupWorkspaces")) {
							var bw = root_obj.get_object_member ("backupWorkspaces");
							if (bw != null && bw.has_member ("folders")) {
								foreach (var f_node in bw.get_array_member ("folders").get_elements ()) {
									if (f_node.get_node_type () == Json.NodeType.OBJECT) {
										var f_obj = f_node.get_object ();
										if (f_obj.has_member ("folderUri"))
											add_recent_candidate (f_obj.get_string_member ("folderUri"), result, seen);
									}
								}
							}
						}

						if (root_obj.has_member ("profileAssociations")) {
							var pa = root_obj.get_object_member ("profileAssociations");
							if (pa != null && pa.has_member ("workspaces")) {
								var ws_obj = pa.get_object_member ("workspaces");
								if (ws_obj != null) {
									var members = ws_obj.get_members ();
									var ws_list = new Gee.ArrayList<string> ();
									foreach (unowned string m in members)
										ws_list.add (m);
									for (int i = ws_list.size - 1; i >= 0; i--)
										add_recent_candidate (ws_list[i], result, seen);
								}
							}
						}
					} catch {}
				}
				return;
			}

			// 3. JetBrains IDEs & Huawei DevEco Studio (~/.config/<Vendor>/<IDE>/options/recentProjects.xml)
			string? jb_vendor = "JetBrains";
			string? jb_prefix = null;
			if (lower_key.contains ("deveco") || exec_bin.contains ("deveco")) {
				jb_vendor = "Huawei";
				jb_prefix = "DevEcoStudio";
			} else if (lower_key.contains ("webstorm") || exec_bin.contains ("webstorm"))
				jb_prefix = "WebStorm";
			else if (lower_key.contains ("intellij") || lower_key.contains ("idea") || exec_bin.contains ("idea"))
				jb_prefix = "IntelliJIdea";
			else if (lower_key.contains ("pycharm") || exec_bin.contains ("pycharm"))
				jb_prefix = "PyCharm";
			else if (lower_key.contains ("clion") || exec_bin.contains ("clion"))
				jb_prefix = "CLion";
			else if (lower_key.contains ("goland") || exec_bin.contains ("goland"))
				jb_prefix = "GoLand";
			else if (lower_key.contains ("rider") || exec_bin.contains ("rider"))
				jb_prefix = "Rider";
			else if (lower_key.contains ("rustrover") || exec_bin.contains ("rustrover"))
				jb_prefix = "RustRover";
			else if (lower_key.contains ("phpstorm") || exec_bin.contains ("phpstorm"))
				jb_prefix = "PhpStorm";
			else if (lower_key.contains ("datagrip") || exec_bin.contains ("datagrip"))
				jb_prefix = "DataGrip";

			if (jb_prefix != null) {
				string jb_base = Path.build_filename (config_dir, jb_vendor);
				if (FileUtils.test (jb_base, FileTest.IS_DIR)) {
					try {
						var dir = Dir.open (jb_base, 0);
						string? sub = null;
						string? best_dir = null;
						while ((sub = dir.read_name ()) != null) {
							if (sub.has_prefix (jb_prefix)) {
								if (best_dir == null || strcmp (sub, best_dir) > 0)
									best_dir = sub;
							}
						}
						if (best_dir != null) {
							string xml_path = Path.build_filename (jb_base, best_dir, "options", "recentProjects.xml");
							string xml_content;
							if (FileUtils.get_contents (xml_path, out xml_content)) {
								var jb_paths = new Gee.ArrayList<string> ();
								foreach (unowned string line in xml_content.split ("\n")) {
									string s = line.strip ();
									if (s.has_prefix ("<entry key=\"")) {
										int start = 12;
										int end = s.index_of ("\"", start);
										if (end > start) {
											string p = s.slice (start, end).replace ("$USER_HOME$", home_dir);
											jb_paths.add (p);
										}
									}
								}
								for (int i = jb_paths.size - 1; i >= 0; i--)
									add_recent_candidate (jb_paths[i], result, seen);
							}
						}
					} catch {}
				}
			}
		}

		void append_system_recent (string launcher, string key, Gee.ArrayList<string> result, Gee.HashSet<string> seen)
		{
			string desktop_id = key;
			if (desktop_id.has_suffix (".desktop"))
				desktop_id = desktop_id.slice (0, desktop_id.length - 8);
			string lower_id = desktop_id.down ();
			string exec_bin = extract_launcher_exec_binary (launcher);

			// Extract short token (e.g. "org.kde.dolphin" -> "dolphin")
			string short_id = lower_id;
			int last_dot = lower_id.last_index_of (".");
			if (last_dot >= 0 && last_dot + 1 < lower_id.length)
				short_id = lower_id.slice (last_dot + 1, lower_id.length);

			try {
				var rm = Gtk.RecentManager.get_default ();
				GLib.List<Gtk.RecentInfo> items = rm.get_items ();
				var matched_infos = new Gee.ArrayList<Gtk.RecentInfo> ();

				foreach (var info in items) {
					if (info == null)
						continue;
					unowned string uri = info.get_uri ();
					if (uri == null || !uri.has_prefix ("file://"))
						continue;

					bool app_matched = false;
					string[] apps = info.get_applications ();
					if (apps != null) {
						foreach (unowned string app_name in apps) {
							string an = app_name.down ();
							if (an != "" && (an == lower_id || an == short_id || (exec_bin != "" && an == exec_bin))) {
								app_matched = true;
								break;
							}
							string app_exec;
							uint count;
							time_t time_;
							if (info.get_application_info (app_name, out app_exec, out count, out time_) && app_exec != null) {
								string ae = app_exec.down ();
								if ((exec_bin != "" && ae.contains (exec_bin)) || (short_id.length >= 3 && ae.contains (short_id))) {
									app_matched = true;
									break;
								}
							}
						}
					}

					if (app_matched)
						matched_infos.add (info);
				}

				matched_infos.sort ((a, b) => {
					long diff = (long) b.get_modified () - (long) a.get_modified ();
					return diff > 0 ? 1 : (diff < 0 ? -1 : 0);
				});

				foreach (var info in matched_infos) {
					if (result.size >= MAX_PER_LAUNCHER)
						break;
					add_recent_candidate (info.get_uri (), result, seen);
				}
			} catch {}
		}
	}
}

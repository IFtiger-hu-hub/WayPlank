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
		 * Return existing recent file URIs for launcher (newest first), pruned.
		 */
		public Gee.ArrayList<string> get_recent (string launcher)
		{
			ensure_loaded ();
			var result = new Gee.ArrayList<string> ();
			var key = launcher_key (launcher);
			if (key == "" || !entries.has_key (key))
				return result;

			var list = entries.get (key);
			var kept = new Gee.ArrayList<string> ();
			bool pruned = false;
			foreach (var uri in list) {
				if (!uri_exists (uri)) {
					pruned = true;
					continue;
				}
				kept.add (uri);
				if (result.size < MAX_PER_LAUNCHER)
					result.add (uri);
			}

			if (pruned || kept.size != list.size) {
				entries.set (key, kept);
				save ();
			}

			return result;
		}
	}
}

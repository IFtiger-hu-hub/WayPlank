//
//  Copyright (C) 2011-2012 Robert Dyer, Michal Hruby, Rico Tzschichholz
//  Copyright (C) 2026 Sergio Melas
//  Copyright (C) 2026 史有虎 (IFtiger-hu)
//
//  This file is part of kde-dockbar.
//
//  kde-dockbar is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

namespace Plank
{
	/**
	 * Summons settings of the currently running desktop-session to use for improving
	 * integration like appearance and behaviour.
	 */
	internal class EnvironmentSettings : Object
	{
		static EnvironmentSettings? instance = null;
		
		public static unowned EnvironmentSettings? get_instance ()
		{
			if (instance == null)
				instance = new EnvironmentSettings ();
			
			return instance;
		}
		
		[Description(nick = "show-notifications")]
		public bool ShowNotifications { get; private set; default = true; }
		
		EnvironmentSettings ()
		{
			Object ();
		}
	}
}

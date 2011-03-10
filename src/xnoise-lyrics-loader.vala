/* xnoise-lyrics-loader.vala
 *
 * Copyright (C) 2009-2010  softshaker
 * Copyright (C) 2011  Jörn Magens
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  The Xnoise authors hereby grant permission for non-GPL compatible
 *  GStreamer plugins to be used and distributed together with GStreamer
 *  and Xnoise. This permission is above and beyond the permissions granted
 *  by the GPL license by which Xnoise is covered. If you modify this code
 *  you may extend this exception to your version of the code, but you are not
 *  obligated to do so. If you do not wish to do so, delete this exception
 *  statement from your version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Author:
 * 	softshaker  softshaker googlemail.com
 * 	Jörn Magens
 */

/* TODO: * try different sources in order of their priority if backends fail to find lyrics
	 * ensure everything's radio-stream-proof
	 * make preferences options
	 * lyrics loader should use top prio provider and if it doesn't find lyrics try the next one
*/
//TODO: use priorities
public class Xnoise.LyricsLoader : GLib.Object {
	
	private Providers providers;
	
	private unowned Main xn;
	private string artist;
	private string title;

	private ulong activation_cb = 0;
	
	private class Providers : GLib.Object {
		private List<unowned ILyricsProvider> list = new List<unowned ILyricsProvider>();
		
		public Providers() {
		}
		
		public int count {
			get {
				return (int)(this.list.length());
			}
		}
		
		public bool empty {
			get {
				if(this.list.length() > 0)
					return false;
				return true;
			}
		}
		
		[CCode (has_target = false)]
		private static int compare(ILyricsProvider a, ILyricsProvider b) {
			if(a.priority <  b.priority)
				return -1;
			if(a.priority >  b.priority)
				return 1;
			return 0;
		}
		
		public unowned ILyricsProvider? get_nth(uint n) {
			list.sort(compare);
			return list.nth_data(n);
		}
		
		public void add(ILyricsProvider provider) {
			list.remove(provider);
			list.prepend(provider);
			list.sort(compare);
		}
		
		public void remove(ILyricsProvider provider) {
			list.remove(provider);
			list.sort(compare);
		}
	}
	
	public signal void sign_fetched(string _artist, string _title, string _credits, string _identifier, string _text, string _provider);
	public signal void sign_using_provider(string _provider, string _artist, string _title);

	public LyricsLoader() {
		xn = Main.instance;
		providers = new Providers();
		activation_cb = xn.plugin_loader.sign_plugin_activated.connect(this.on_plugin_activated);
		global.uri_changed.connect( () => {
			n_th_provider = 0;
		});
	}

	private void on_plugin_activated(PluginLoader sender, Plugin p) {
		if(!p.is_lyrics_plugin)
			return;
		unowned ILyricsProvider prov = p.loaded_plugin as ILyricsProvider;
		if(prov == null) 
			return;
		providers.add(prov);
	}

	public void remove_lyrics_provider(ILyricsProvider lp) {
		providers.remove(lp);
	}

	public bool fetch(string _artist, string _title) {
		this.artist = prepare_for_search(_artist);
		this.title  = prepare_for_search(_title);
		
		if(providers.get_nth(n_th_provider) == null) {
			sign_fetched(artist, title, "", "", "", ""); //_("Enable a lyrics provider plugin for lyrics fetching to work")
			return false;
		}
		Idle.add( () => {
			if(artist == null)
				return false;
			ILyrics* p = providers.get_nth(n_th_provider).from_tags(this, artist, title, lyrics_fetched_cb);
			if(p == null)
				return false;
			sign_using_provider(providers.get_nth(n_th_provider).name, artist, title);
			p->find_lyrics();
			return false;
		});
		return true;
	}
	
	private uint n_th_provider = 0;
	
	//forward result
	private void lyrics_fetched_cb(string _artist, string _title, string _credits, string _identifier, string _text, string _providername) {
		//print("got lyrics reply from %s %s %s %s\n", _providername, _artist, _title, _identifier);
		if(prepare_for_comparison(_artist) == prepare_for_comparison(this.artist) && 
		   prepare_for_comparison(_title) == prepare_for_comparison(this.title)) {
			if(_text == null || _text.strip() == "") {
				n_th_provider++;
				if(providers.count > n_th_provider) {
					//print("NEXT lyrics provider\n");
					fetch(artist, title);
					return;
				}
				else {
					n_th_provider = 0;
					sign_fetched(_artist, _title, "", _identifier, "no lyrics found...", _providername); // the 'no lyrics found...' also appears in the db provider !! 
				}
			}
			else {
				n_th_provider = 0;
				sign_fetched(_artist, _title, _credits, _identifier, _text, _providername);
			}
		}
		else {
			// is there some reaction necessary?
			n_th_provider = 0;
		}
	}
}


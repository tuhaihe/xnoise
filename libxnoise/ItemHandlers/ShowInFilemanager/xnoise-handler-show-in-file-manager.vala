/* xnoise-handler-show-in-file-manager.vala
 *
 * Copyright (C) 2012  Jörn Magens
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
 *     Jörn Magens
 */

// ItemHandler Implementation 
// provides the right Action for the given ActionContext/ItemType
public class Xnoise.HandlerShowInFileManager : ItemHandler {
    private Action a;
    private const string ainfo = _("Show in parent folder");
    private const string aname = "A HandlerShowInFileManagername";

    private Action b;
    private const string binfo = _("Show in parent folder");
    private const string bname = "B HandlerShowInFileManagername";
    
    private const string name = "HandlerShowInFileManager";
    
    public HandlerShowInFileManager() {
        a = new Action();
        a.action = show_uri;
        a.info = this.ainfo;
        a.name = this.aname;
        a.stock_item = Gtk.Stock.OPEN;
        a.context = ActionContext.TRACKLIST_MENU_QUERY;

        b = new Action();
        b.action = show_uri;
        b.info = this.binfo;
        b.name = this.bname;
        b.stock_item = Gtk.Stock.OPEN;
        b.context = ActionContext.QUERYABLE_TREE_MENU_QUERY;
        
    }

    public override ItemHandlerType handler_type() {
        return ItemHandlerType.MENU_PROVIDER;
    }
    
    public override unowned string handler_name() {
        return name;
    }

    public override unowned Action? get_action(ItemType type, ActionContext context, ItemSelectionType selection = ItemSelectionType.NOT_SET) {
        if((context == ActionContext.TRACKLIST_MENU_QUERY) &&
           (type == ItemType.LOCAL_AUDIO_TRACK || type == ItemType.LOCAL_VIDEO_TRACK))
            return a;
        if((context == ActionContext.QUERYABLE_TREE_MENU_QUERY) &&
           (type == ItemType.LOCAL_AUDIO_TRACK || type == ItemType.LOCAL_VIDEO_TRACK))
            return b;
        return null;
    }

    private void show_uri(Item item, GLib.Value? data) { 
        if(item.type != ItemType.LOCAL_AUDIO_TRACK && item.type != ItemType.LOCAL_VIDEO_TRACK) 
            return;
        
        try {
            File f = File.new_for_uri(item.uri);
            Gtk.show_uri(null, f.get_parent().get_uri(), Gdk.CURRENT_TIME);
        }
        catch(GLib.Error e) {
            print("%s\n", e.message);
        }
    }
}


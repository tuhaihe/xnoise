/* xnoise-tag-artistalbum-editor.vala
 *
 * Copyright (C) 2011 - 2012  Jörn Magens
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

using Gtk;

using Xnoise;
using Xnoise.Services;
using Xnoise.TagAccess;


internal class Xnoise.TagArtistAlbumEditor : GLib.Object {
    private unowned Xnoise.Main xn;
    private Dialog dialog;
    private Gtk.Builder builder;
    private string new_content_name = null;
    private unowned MusicBrowserModel mbm = null;
    
    private Entry entry;
    
    
    private Item? item;
    
    public signal void sign_finish();

    public TagArtistAlbumEditor(Item _item) {
        this.item = _item;
        xn = Main.instance;
        td_old = {};
        builder = new Gtk.Builder();
        create_widgets();
        mbm = main_window.musicBr.mediabrowsermodel;
        mbm.notify["populating-model"].connect( () => {
            if(!global.media_import_in_progress && !mbm.populating_model)
                infolabel.label = EMPTYSTRING;
        });
        global.notify["media-import-in-progress"].connect( () => {
            if(!global.media_import_in_progress && !mbm.populating_model)
                infolabel.label = EMPTYSTRING;
        });
        
        fill_entries();
        dialog.set_position(Gtk.WindowPosition.CENTER_ON_PARENT);
        dialog.show_all();
    }
    
    private void fill_entries() {
        Worker.Job job;
        job = new Worker.Job(Worker.ExecutionType.ONCE_HIGH_PRIORITY, this.query_trackdata_job);
        job.item = item;
        db_worker.push_job(job);
    }

    private TrackData[] td_old;
    
    private bool query_trackdata_job(Worker.Job job) {
        // callback for query in other thread
        td_old = item_converter.to_trackdata(this.item, global.searchtext);
        
        TrackData td = td_old[0];
        switch(item.type) {
            case ItemType.COLLECTION_CONTAINER_ARTIST:
                Idle.add( () => {
                    // put data to entry
                    entry.text  = td.artist;
                    return false;
                });
                break;
            case ItemType.COLLECTION_CONTAINER_ALBUM:
                Idle.add( () => {
                    // put data to entry
                    entry.text  = td.album;
                    return false;
                });
                break;
            default:
                Idle.add( () => {
                    sign_finish();
                    return false;
                });
                break;
        }
        return false;
    }

    private Label infolabel;
    private void create_widgets() {
        try {
            dialog = new Dialog();
            
            dialog.set_modal(true);
            dialog.set_transient_for(main_window);
            
            builder.add_from_file(Config.UIDIR + "metadat_artist_album.ui");
            
            var mainvbox           = builder.get_object("vbox1")           as Gtk.Box;
            var okbutton           = builder.get_object("okbutton")        as Gtk.Button;
            var cancelbutton       = builder.get_object("cancelbutton")    as Gtk.Button;
            entry                  = builder.get_object("entry1")          as Gtk.Entry;
            infolabel              = builder.get_object("label5")          as Gtk.Label;
            var explainer_label    = builder.get_object("explainer_label") as Gtk.Label;
            var content_label      = builder.get_object("content_label")   as Gtk.Label;
            
            ((Gtk.Box)this.dialog.get_content_area()).add(mainvbox);
            okbutton.clicked.connect(on_ok_button_clicked);
            cancelbutton.clicked.connect(on_cancel_button_clicked);
            
            this.dialog.set_default_icon_name("xnoise");
            this.dialog.set_title(_("xnoise - Edit metadata"));
            switch(item.type) {
                case ItemType.COLLECTION_CONTAINER_ARTIST:
                    explainer_label.label = _("Type new artist name.");
                    content_label.label = _("Artist:");
                    break;
                case ItemType.COLLECTION_CONTAINER_ALBUM:
                    explainer_label.label = _("Type new album name.");
                    content_label.label = _("Album:");
                    break;
                default:
                    break;    
            }
        }
        catch (GLib.Error e) {
            var msg = new Gtk.MessageDialog(null,
                                            Gtk.DialogFlags.MODAL,
                                            Gtk.MessageType.ERROR,
                                            Gtk.ButtonsType.CANCEL,
                                            "Failed to build dialog! %s\n".printf(e.message));
            msg.run();
            return;
        }
    }
    
    private void on_ok_button_clicked(Gtk.Button sender) {
        if(mbm.populating_model) {
            infolabel.label = _("Please wait while filling media browser. Or cancel, if you do not want to wait.");
            return;
        }
        if(global.media_import_in_progress) {
            infolabel.label = _("Please wait while importing media. Or cancel, if you do not want to wait.");
            return;
        }
        infolabel.label = EMPTYSTRING;
        if(entry.text != null && entry.text.strip() != EMPTYSTRING)
            new_content_name = entry.text.strip();
        // TODO: UTF-8 validation
        switch(item.type) {
            case ItemType.COLLECTION_CONTAINER_ARTIST:
                do_artist_rename();
                break;
            case ItemType.COLLECTION_CONTAINER_ALBUM:
                do_album_rename();
                break;
            default:
                break;    
        }
        Idle.add( () => {
            this.dialog.destroy();
            return false;
        });
    }
    
//    private void do_artist_case_correction() {
//        var job = new Worker.Job(1, Worker.ExecutionType.ONCE, null, this.do_artist_case_correction_job);
//        job.set_arg("new_content_name", new_content_name);
//        job.set_arg("org_content_name", org_content_name);
//        job.set_arg("treerowref", treerowref);
//        db_worker.push_job(job);
//    }
//    
//    private void do_artist_case_correction_job(Worker.Job job) {
//        string oldname = (string)job.get_arg("org_content_name");
//        string newname = (string)job.get_arg("new_content_name");
//        media_importer.update_artist_name(oldname, newname); // For case corrections

//        string[] uris_for_update = media_importer.get_uris_for_artist(newname);
//        //foreach(string s in uris_for_update)
//        //    print("cccc_ %s\n", s);
//        var tagjob = new Worker.Job(1, Worker.ExecutionType.ONCE, null, this.do_artist_tag_case_correction_job);
//        tagjob.set_arg("artist", newname);
//        tagjob.set_arg("uris_for_update", uris_for_update);
//        db_worker.push_job(tagjob);
//        
//        Idle.add( () => {
//            TreeRowReference tf = (TreeRowReference)job.get_arg("treerowref");
//            TreeIter iter;
//            TreePath path  = tf.get_path();
//            MusicBrowserModel mtmp = (MusicBrowserModel)tf.get_model();
//            mtmp.get_iter(out iter, path);
//            mtmp.set(iter, MusicBrowserModel.Column.VIS_TEXT, newname);    
//            return false;
//        });
//    }

//    private void do_album_case_correction() {
//        TreeIter artist_iter, album_iter;
//        string artist = EMPTYSTRING;
//        TreePath path  = treerowref.get_path();
//        mbm.get_iter(out album_iter, path);
//        mbm.iter_parent(out artist_iter, album_iter);
//        mbm.get(artist_iter, MusicBrowserModel.Column.VIS_TEXT, ref artist);

//        var job = new Worker.Job(1, Worker.ExecutionType.ONCE, null, this.do_album_case_correction_job);
//        job.set_arg("artist", artist);
//        job.set_arg("new_content_name", new_content_name);
//        job.set_arg("org_content_name", org_content_name);
//        job.set_arg("treerowref", treerowref);
//        db_worker.push_job(job);
//    }

//    private void do_album_case_correction_job(Worker.Job job) {
//        string oldname = (string)job.get_arg("org_content_name");
//        string newname = (string)job.get_arg("new_content_name");
//        string artist  = (string)job.get_arg("artist");
//        
//        media_importer.update_album_name(artist, oldname, newname); // For case corrections

//        string[] uris_for_update = media_importer.get_uris_for_artistalbum(artist, newname);
//        //foreach(string s in uris_for_update)
//        //    print("cccc_ %s\n", s);
//        var tagjob = new Worker.Job(1, Worker.ExecutionType.ONCE, null, this.do_album_tag_case_correction_job);
//        tagjob.set_arg("album", newname);
//        tagjob.set_arg("uris_for_update", uris_for_update);
//        db_worker.push_job(tagjob);
//        
//        Idle.add( () => {
//            TreeRowReference tf = (TreeRowReference)job.get_arg("treerowref");
//            TreeIter iter;
//            TreePath path  = tf.get_path();
//            MusicBrowserModel mtmp = (MusicBrowserModel)tf.get_model();
//            mtmp.get_iter(out iter, path);
//            mtmp.set(iter, MusicBrowserModel.Column.VIS_TEXT, newname);    
//            return false;
//        });
//    }
//    
//    private void do_album_tag_case_correction_job(Worker.Job job) {
//        string album = (string)job.get_arg("album");
//        foreach(string s in ((string[])job.get_arg("uris_for_update"))) {
//            //print("%s\n", s);
//            File f = File.new_for_uri(s);
//            TagWriter tw = new TagWriter();
//            if(!tw.write_album(f, album))
//                print("Error writing tag for '%s'\n", s);
//        }
//    }

//    private void do_artist_tag_case_correction_job(Worker.Job job) {
//        string artist = (string)job.get_arg("artist");
//        foreach(string s in ((string[])job.get_arg("uris_for_update"))) {
//            //print("%s\n", s);
//            File f = File.new_for_uri(s);
//            TagWriter tw = new TagWriter();
//            if(!tw.write_artist(f, artist))
//                print("Error writing tag for '%s'\n", s);
//        }
//    }

    private void do_artist_rename() {
        var job = new Worker.Job(Worker.ExecutionType.ONCE, this.update_tags_job);
        job.set_arg("new_content_name", new_content_name);
        job.item = this.item;
        db_worker.push_job(job);
    }

    private void do_album_rename() {
        var job = new Worker.Job(Worker.ExecutionType.ONCE, this.update_tags_job);
        job.set_arg("new_content_name", new_content_name);
        job.item = this.item;
        db_worker.push_job(job);
    }


    private bool update_tags_job(Worker.Job tag_job) {
        if(tag_job.item.type == ItemType.COLLECTION_CONTAINER_ARTIST) {
            var job = new Worker.Job(Worker.ExecutionType.ONCE, this.update_filetags_job);
            //print("%s %d\n", tag_job.item.type.to_string(), tag_job.item.db_id);
            job.track_dat = item_converter.to_trackdata(tag_job.item, global.searchtext);
            if(job.track_dat == null)
                return false;
            job.item = tag_job.item;
            foreach(TrackData td in job.track_dat)
                td.artist = new_content_name;
            print("push filetags job\n");
            io_worker.push_job(job);
        }
        else if(tag_job.item.type == ItemType.COLLECTION_CONTAINER_ALBUM) {
            var job = new Worker.Job(Worker.ExecutionType.ONCE, this.update_filetags_job);
            job.track_dat = item_converter.to_trackdata(tag_job.item, global.searchtext);
            if(job.track_dat == null)
                return false;
            job.item = tag_job.item;
            foreach(TrackData td in job.track_dat)
                td.album = new_content_name;
            io_worker.push_job(job);
        }
        return false;
    }

    private bool update_filetags_job(Worker.Job job) {
        //print("job.track_dat len : %d\n", job.track_dat.length);
        if(job.track_dat.length > 0) {
            var bjob = new Worker.Job(Worker.ExecutionType.ONCE, this.begin_job);
            db_worker.push_job(bjob);
        }
        for(int i = 0; i<job.track_dat.length; i++) {
            File f = File.new_for_uri(job.track_dat[i].item.uri);
            var tw = new TagWriter();
            bool ret = false;
            //print("%s\n", job.item.type.to_string());
            if(job.item.type == ItemType.COLLECTION_CONTAINER_ARTIST)
                ret = tw.write_artist(f, job.track_dat[i].artist);
            if(job.item.type == ItemType.COLLECTION_CONTAINER_ALBUM)
                ret = tw.write_album(f, job.track_dat[i].album);
            if(ret) {
                var dbjob = new Worker.Job(Worker.ExecutionType.ONCE, this.update_db_job);
                TrackData td = job.track_dat[i];
                dbjob.set_arg("td", td);
                dbjob.item = job.item;
                db_worker.push_job(dbjob);
            }
        }
        var fin_job = new Worker.Job(Worker.ExecutionType.ONCE, this.finish_job);
        
        db_worker.push_job(fin_job);
        return false;
    }
    
    private bool begin_job(Worker.Job job) {
        db_writer.begin_transaction();
        return false;
    }
    
    private bool finish_job(Worker.Job job) {
        db_writer.commit_transaction();
        Timeout.add(200, () => {
            main_window.musicBr.mediabrowsermodel.filter();
            return false;
        });
        Timeout.add(300, () => {
            this.sign_finish();
            return false;
        });
        return false;
    }

    private bool update_db_job(Worker.Job job) {
        TrackData td = (TrackData)job.get_arg("td");
        media_importer.update_item_tag(ref job.item, ref td);
        return false;
    }

    private void on_cancel_button_clicked(Gtk.Button sender) {
        Idle.add( () => {
            this.dialog.destroy();
            this.sign_finish();
            return false;
        });
    }
}


# -*- coding: utf-8 -*-
'''
XBMC Playback Resumer
Copyright (C) 2014 BradVido

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
'''
import xbmc
import xbmcaddon
import xbmcgui
import os
import json
import time
from random import randint
import sqlite3

__addon__        = xbmcaddon.Addon()
__addonversion__ = __addon__.getAddonInfo('version')
__addonid__      = __addon__.getAddonInfo('id')
__addonname__    = __addon__.getAddonInfo('name')

def log(msg):
    fh = open("/tmp/ll.txt", "a")
    fh.write(str(msg) + "\n")
    fh.close()

class Main(object):
    def __init__(self, *args):
        self.db = "/storage/.kodi/userdata/Database/MyVideos90.db"
        self.conn = sqlite3.connect(self.db)
        self._create_resumer()
        pass

    def _create_resumer(self):
        c = self.conn.cursor()
        # One time
        try:
            c.execute("CREATE TABLE resumer (idResumer integer, strFullFilename text)")
            c.execute("INSERT into resumer values (1, '')")
            #c.execute("select idResumer from resumer")
            #ret = c.fetchone()
            #if not ret:
            #    c.execute("INSERT into resumer values (1, '')")
            self.conn.commit()
        except:
            pass
        c.close()

    def updateResumer(self, filename, nowPlaying):
        log("updating resumer table: %s %s" % (filename, nowPlaying))
        c = self.conn.cursor()
        c.execute("select strFullFilename from resumer WHERE idResumer=1")
        ret = c.fetchone()

        # We are still playing
        if nowPlaying:
            if ret and ret[0] == filename:
                return
            c.execute("UPDATE resumer SET strFullFilename='%s' WHERE idResumer=1" % (filename))
            self.conn.commit()
            return
        else:
            # Not playing anymore
            if not ret:
                return
            c.execute("UPDATE resumer SET strFullFilename='' WHERE idResumer=1")
            self.conn.commit()
            return
        return

    def resume_playing(self):
        c = self.conn.cursor()
        c.execute("select strFullFilename from resumer WHERE idResumer=1")
        ret = c.fetchone()
        if not ret:
            log("ERROR: Record deleted in resumer")
            return
        if ret[0] == '':
            return

        # Now we need to resume playing this video file
        filename = ret[0]
        resumeTime = self.getLastPlayTime(filename)
        if not resumeTime:
            return
        strTimestamp = str(int(resumeTime / 60))+":"+("%02d" % (resumeTime % 60))

        log("resuming last played video: %s %f" % (filename, resumeTime))
        xbmc.Player().play(filename)
        time.sleep(2)
        for i in range(0, 1000):        #wait up to 10 secs for the video to start playing befor we try to seek
            if not xbmc.Player().isPlayingVideo() and not xbmc.abortRequested:
                xbmc.sleep(100)
            else:
                xbmc.Player().seekTime(resumeTime)
                time.sleep(2)
                xbmc.executebuiltin('Notification(Resuming Playback!,At '+strTimestamp+',5000)')
                return
        xbmc.executebuiltin('Notification(Resume Playback failed,3000)')
        return

    # Insert records if it does not exist for path, files and bookmark
    def _insert_record(self, path, filename):
        # First get path. If not insert
        c = self.conn.cursor()
        c.execute("select idPath from path where strPath='%s'" % (path))
        pret = c.fetchone()
        if not pret:
            ret = c.execute("insert into path (strPath) values ('%s')" % (path)) 
            self.conn.commit()
            c.execute("select idPath from path where strPath='%s'" % (path))
            pret = c.fetchone()

        # Get files, if not insert
        c = self.conn.cursor()
        c.execute("select idFile from files where strfilename='%s'" % (filename))
        fret = c.fetchone()
        if not fret:
            ret = c.execute("insert into files (idPath, strFileName) values (%d, '%s')" % (pret[0], filename))
            self.conn.commit()
            c.execute("select idFile from files where strfilename='%s'" % (filename))
            fret = c.fetchone()





    def updatePlayTime(self, filename, playtime):
        (path, fname) = os.path.split(filename)
        if not path and fname:
            return
        path = path + "/"
        c = self.conn.cursor()
        c.execute("select idBookmark,timeInSeconds from bookmark where idFile=(select idFile from files where strFilename='%s' and idPath=(select idPath from path where strPath='%s'))" % (fname, path))
        ret = c.fetchone()
        if ret:
            ret = c.execute("update bookmark SET timeInSeconds=%f where idBookmark=%d" % (playtime, ret[0]))
            self.conn.commit()
        else:
            self._insert_record(path, fname)
            # Insert a bookmark record
            c.execute("select idFile from files where strFilename='%s' and idPath=(select idPath from path where strPath='%s')" % (fname, path))
            ret = c.fetchone()
            if ret:
                # ( idBookmark integer primary key, idFile integer, timeInSeconds double, totalTimeInSeconds double, thumbNailImage text, player text, playerState text, type integer)
                c.execute("insert into bookmark (idFile, timeInSeconds, totalTimeInSeconds, player, type) values (%d, %f, %f, 'DVDPlayer', 1)" % (ret[0], playtime, xbmc.Player().getTotalTime()))
                self.conn.commit()

    def getLastPlayTime(self, filename):
        (path, fname) = os.path.split(filename)
        if not path and fname:
            return None
        path = path + "/"
        c = self.conn.cursor()
        c.execute("select idBookmark,timeInSeconds from bookmark where idFile=(select idFile from files where strFilename='%s' and idPath=(select idPath from path where strPath='%s'))" % (fname, path))
        ret = c.fetchone()
        if ret:
            return ret[1]
        return None

mn = Main()


class MyPlayer( xbmc.Player ):
    def __init__( self, *args ):
        xbmc.Player.__init__( self )
        self.filename = ""
        log('MyPlayer - init')

    def _do_update(self):
        filename = xbmc.Player().getPlayingFile()
        playtime = xbmc.Player().getTime()
        mn.updatePlayTime(filename, playtime)
        log("Updating playtime " + filename + " " + str(playtime))

    def onPlayBackPaused( self ):
        log('Playback Paused');
        self._do_update()

    def onPlayBackEnded( self ):#video ended normally (user didn't stop it)
        log("Playback ended")
        mn.updateResumer(self.filename, 0)
        self.filename = ""

    def onPlayBackStopped( self ):
        log("Playback stopped")
        mn.updateResumer(self.filename, 0)
        self.filename = ""

    def onPlayBackSeek( self, tm, seekOffset ):
        log("Playback seeked (tm)")
        self._do_update()

    def onPlayBackSeekChapter( self, chapter ):
        log("Playback seeked (chapter)")

    def onPlayBackStarted( self ):
        log("Playback started")
        self.filename = xbmc.Player().getPlayingFile()
        mn.updateResumer(self.filename, 1)
        xbmc.sleep(2000)

        while xbmc.Player().isPlayingVideo() and not xbmc.abortRequested:
            self._do_update()
            xbmc.sleep(30000)

class MyMonitor( xbmc.Monitor ):
    def __init__( self, *args, **kwargs ):
        xbmc.Monitor.__init__( self )
        log('MyMonitor - init')

    def onSettingsChanged( self ):
        log("Settings Changed")
        pass
        #loadSettings()

    def onAbortRequested(self):
        log("Abort Requested!")

xbmc_monitor = MyMonitor()
player_monitor = MyPlayer()

mn.resume_playing()

while not xbmc.abortRequested:
    xbmc.sleep(100)


from __future__ import unicode_literals

import sys

import os.path
path = os.path.realpath(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(os.path.dirname(path)))

import youtube_dl

ydl_opts = {
    'noplaylist': True,
    'forcefilename': True,
    'restrictfilenames': True,
    'outtmpl': '/Users/k.tupitsin/Library/Application Support/uproar-mac/videos/%(id)s.%(ext)s',
}
with youtube_dl.YoutubeDL(ydl_opts) as ydl:
    ydl.download(['https://www.youtube.com/watch?v=doAcaKGeQwI'])

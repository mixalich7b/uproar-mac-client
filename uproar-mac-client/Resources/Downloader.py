from __future__ import unicode_literals

import sys

import os.path
path = os.path.realpath(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(os.path.dirname(path)))

import youtube_dl

finalFilepath = None

def getFinalFilepath():
    return finalFilepath

def progress_hooks(progress):
    global finalFilepath
    if progress['status'] == 'finished':
        finalFilepath = progress['filename']
        print('Downloaded: %s' % getFinalFilepath())

ydl_opts = {
    'noplaylist': True,
    'forcefilename': True,
    'restrictfilenames': True,
    'outtmpl': '/Users/k.tupitsin/Library/Application Support/uproar-mac/videos/%(id)s.%(ext)s',
    'writeinfojson': True,
    'progress_hooks': [progress_hooks]
}
with youtube_dl.YoutubeDL(ydl_opts) as ydl:
    ydl.download(sys.argv)


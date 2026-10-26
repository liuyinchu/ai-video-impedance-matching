#!/usr/bin/ruby
# encoding: UTF-8
require 'webrick'
require 'fileutils'
root=File.expand_path('..',__dir__)
FileUtils.mkdir_p(File.join(root,'build'))
log=File.open(File.join(root,'build','preview-access.log'),'a')
log.sync=true
mime=WEBrick::HTTPUtils::DefaultMimeTypes.merge('mp4'=>'video/mp4','m4a'=>'audio/mp4','mp3'=>'audio/mpeg','srt'=>'application/x-subrip','json'=>'application/json','html'=>'text/html')
server=WEBrick::HTTPServer.new(
  BindAddress:'127.0.0.1',Port:Integer(ENV.fetch('PREVIEW_PORT','18786')),
  DocumentRoot:File.join(root,'output'),MimeTypes:mime,
  AccessLog:[[log,'%t "%r" %s %b range="%{Range}i"']],
  RequestCallback:proc{|req,res|
    res['Cache-Control']='no-store'
    res['Accept-Ranges']='bytes' if req.path.end_with?('.mp4')
  })
trap('INT'){server.shutdown}
trap('TERM'){server.shutdown}
server.start

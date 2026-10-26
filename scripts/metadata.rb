#!/usr/bin/ruby
require 'json'
require 'fileutils'
Dir.chdir(File.expand_path('..', __dir__))
timeline=JSON.parse(File.read('build/timeline.json'))
speech=JSON.parse(File.read('build/speech-provider.json'))
stamp=lambda { |v| n=v.floor; '%02d:%02d' % [n/60,n%60] }
chapters=timeline.map { |s| {'start'=>s['start'],'time'=>stamp.call(s['start']),'title'=>s['scene']['title']} }
File.write('output/chapters.json',JSON.pretty_generate(chapters)+"\n")
File.write('output/chapters.txt',chapters.map { |c| c['time']+' '+c['title'] }.join("\n")+"\n")
File.write('content/script.md',"# 阻抗匹配｜分镜与旁白\n\n"+timeline.map { |s|
  "## "+stamp.call(s['start'])+" "+s['scene']['title']+"\n\n"+s['scene']['subtitle']+"\n\n"+s['scene']['narration'].join("\n\n")
}.join("\n\n")+"\n")
meta={'title'=>'阻抗匹配：为什么接通了，信号还会回来？','duration'=>timeline.last['start']+timeline.last['duration'],'width'=>1280,'height'=>720,'fps'=>30,'scenes'=>timeline.size,'provider'=>speech['provider'],'voice'=>speech['voice'],'rate'=>speech['rate'],'date'=>'2026-10-26'}
File.write('output/metadata.json',JSON.pretty_generate(meta)+"\n")
puts "Metadata: #{meta['duration'].round(2)} seconds / #{chapters.size} chapters"

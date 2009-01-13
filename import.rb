#!/usr/bin/ruby
require "find"
require "fileutils"
require "optparse"

=begin
= 写真取り込みスクリプト
(1) 指定ディレクトリ以下のRAWとJPEGファイルをflistに
(2) タイムスタンプ逆順にソートしてslistに
(3) slistの隣同士を見て一定時間以内の撮影なら同一イベントとみなして同一IDを割り当てる
(4) ID判別で直近イベントと思われる写真のリストをCamera.latestで返す
(5) ID判別でn回前のイベントと思われる写真のリストをCamera.event(n)で返す

* デフォルトでは直近から5回前までのイベントの写真枚数と時間を表示
* -cオプションでカレントディレクトリに取り込み
* -mオプションでカレントディレクトリに取り込んで、オリジナルは削除

= 今後やりたい
=end

# PHOTO_DIR = "/media/disk/DCIM/" 
PHOTO_DIR = "/home/ken/desktop/"
HOURS = 1.0  # 同一イベントの撮影とみなすシャッター間隔

# default options
Options = {
  :photo_dir => PHOTO_DIR,
  :hours     => HOURS,
  :copy      => false,
  :move      => false,
  :events    => (1..5),
  :verbose   => false,
}

class Camera

  def initialize(dir=PHOTO_DIR)
    @dir = dir
    @flist = []   # [fullpath, mtime]
    @slist = []   # time sorted flist [fullpath, mtime, event_id]
    make_list
    time_sort
  end

  def make_list
    Find.find(@dir){|f|
      if (File.ftype(f) == "file") &&
          (f =~ /.*jpg/i) || (f =~ /.*txt/i)
        @flist.push [f,File.mtime(f)]
      end
    }
  rescue => ex
    print ex.message, "\n"
    exit
  end

  def time_sort
    @slist = @flist.sort {|x,y|
      x[1] <=> y[1]
    }.reverse

    t = @slist[0][1]
    @count = 1

    @slist.each {|file|
      if (((t - file[1]).to_f / 3600) > Options[:hours])
        @count += 1
      end
      file.push(@count)
      t = file[1]
    }
  end

  def event(num)
    slist.find_all {|file| file[2] == num}
  end

  def latest
    self.event(1)
  end

  protected :make_list, :time_sort
  attr_reader :flist, :slist
end

# parse options

def parse_option
  opts = OptionParser.new
  opts.on("-c", "--copy",
          "copy the photos, instead of just showing"){|val| Options[:copy] = true}
  opts.on("-m", "--move",
          "move the photos, instead of just showing"){|val| Options[:move] = true}
  opts.on("-t [duration]", "--time",
          "set the duration hours of event"){|val| Options[:hours] = val.to_f}
  opts.on("-e [number expression]", "--event",
          "set the events to show/import"){|val|
    numbers = []
    if val =~ /[^0-9\,\-]/
      puts "Error! allowed expressions for -e option are: 1,2,5-7..."
      exit 
    end
    val.split(",").each{|exp|
      if exp =~ /(\d)-(\d)/
        numbers = Range.new($1.to_i,$2.to_i).to_a
      else
        numbers << exp
      end
    }
    Options[:events] = numbers
  }
  opts.on("-l", "--latest",
          "set the event to the latest"){|val| Options[:events] = [1] }
  opts.on("-v", "--verbose",
          "verbose mode"){|val| Options[:verbose] = true }
opts.parse!(ARGV)
end

# main

parse_option
nikon = Camera.new

if Options[:verbose]
  print "Duration of each event is set to #{Options[:hours]} hour(s)\n\n"
end

if Options[:copy] || Options[:move]
  f = Proc.new {|src,dest,opt|
    case
    when Options[:copy]
      FileUtils.cp(src,dest,opt)
    when Options[:move]
      FileUtils.mv(src,dest,opt)
    end
  }
  Options[:events].each {|n|
    nikon.event(n).each {|photo|
      f.call(photo[0],".",
             {:verbose => Options[:verbose]})
    }
  }
else
  Options[:events].each {|n|
    number = nikon.event(n).size
    print "Event",n, "(#{number}): "
    print nikon.event(n)[number-1][1].strftime("%m/%d %H:%M - ")
    print nikon.event(n)[0][1].strftime("%m/%d %H:%M")
    print "\n"
  }
end

#!/usr/bin/ruby
require "find"
require "fileutils"
require "optparse"

=begin
= Photo import script
(1) flist: filenames of RAWs and JPEGs under a given directory
(2) slit: sorted photo filenames by time, descending order. 
(3) compare the adjacent photos, if the time difference is under a
given duration, give those the same ID.
(4) Camera.latest: The list of photos that are in the most recent event group. 
(5) Camera.event(n): The list of photos in the Nth former event. 

* by default, it displays the number of photos for the 5 recent events. 
* -c: copy photos to the current directory. 
* -m: move photos to the current directory. 

=end

PHOTO_DIR = "/media/disk/DCIM/" 
HOURS = 1.0  # time duration for with a pair of photos are considered
             # to be taken at the same event

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

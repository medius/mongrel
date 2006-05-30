# Mongrel Web Server - A Mostly Ruby Webserver and Library
#
# Copyright (C) 2005 Zed A. Shaw zedshaw AT zedshaw dot com
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'test/unit'
require 'net/http'
require 'mongrel'
require 'timeout'
require File.dirname(__FILE__) + "/testhelp.rb"

class SimpleHandler < Mongrel::HttpHandler
  def process(request, response)
    response.start do |head,out|
      head["Content-Type"] = "text/html"
      results = "<html><body>Your request:<br /><pre>#{request.params.to_yaml}</pre><a href=\"/files\">View the files.</a></body></html>"
      out << results
    end
  end
end

class DumbHandler < Mongrel::HttpHandler
  def process(request, response)
    response.start do |head,out|
      head["Content-Type"] = "text/html"
      out.write("test")
    end
  end
end

def check_status(results, expecting)
  results.each do |res|
    assert(res.kind_of?(expecting), "Didn't get #{expecting}, got: #{res.class}")
  end
end

class HandlersTest < Test::Unit::TestCase

  def setup
    stats = Mongrel::StatisticsFilter.new(:sample_rate => 1)

    @config = Mongrel::Configurator.new :host => '127.0.0.1', :port => 9998 do
      listener do
        uri "/", :handler => SimpleHandler.new
        uri "/", :handler => stats
        uri "/404", :handler => Mongrel::Error404Handler.new("Not found")
        uri "/dumb", :handler => Mongrel::DeflateFilter.new(:always_deflate => true)
        uri "/dumb", :handler => DumbHandler.new, :in_front => true
        uri "/files", :handler => Mongrel::DirHandler.new("doc")
        uri "/files_nodir", :handler => Mongrel::DirHandler.new("doc",listing_allowed=false, index_html="none")
        uri "/status", :handler => Mongrel::StatusHandler.new(:stats_filter => stats)
      end
    end
    @config.run
  end

  def teardown
    @config.stop
  end

  def test_more_web_server
    res = hit([ "http://localhost:9998/test",
          "http://localhost:9998/dumb",
          "http://localhost:9998/404",
          "http://localhost:9998/files/rdoc/index.html",
          "http://localhost:9998/files/rdoc/nothere.html",
          "http://localhost:9998/files/rdoc/",
          "http://localhost:9998/files_nodir/rdoc/",
          "http://localhost:9998/status",
    ])

    check_status res, String
  end

  def test_deflate_access
    req = Net::HTTP::Get.new("http://localhost:9998/dumb")
  end

  # TODO: find out why this fails on win32 but nowhere else
  #
  #def test_posting_fails_dirhandler
  #  req = Net::HTTP::Post.new("http://localhost:9998/files/rdoc/")
  #  req.set_form_data({'from'=>'2005-01-01', 'to'=>'2005-03-31'}, ';')
  #  res = hit [["http://localhost:9998/files/rdoc/",req]]
  #  check_status res, Net::HTTPNotFound
  #end

  def test_unregister
    @config.listeners["127.0.0.1:9998"].unregister("/")
  end
end

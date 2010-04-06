require 'rubygems'
require 'test/unit'
require 'active_record'

$:.unshift "#{File.dirname(__FILE__)}/../lib/"
require 'acts_as_list'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

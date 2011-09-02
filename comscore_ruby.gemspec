# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "comscore-ruby/version"

Gem::Specification.new do |s|
  s.name        = "comscore_ruby"
  s.version     = ComScore::VERSION
  s.authors     = ["Mike Sukmanowsky"]
  s.email       = ["mike.sukmanowsky@gmail.com"]
  s.homepage    = "https://github.com/msukmanowsky/comscore_ruby/wiki"
  s.summary     = "Use comScore's SOAP API in a manner that does not require you to bang your head against a wall."
  s.description = "Basic support for things like finding media, media sets (AKA categories), and fetching reports.  Documentation is...well...missing so far."

  s.rubyforge_project = s.name

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "savon"
  s.add_runtime_dependency "active_support"
  
  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end

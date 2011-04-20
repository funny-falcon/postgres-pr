# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "postgres-pr/version"

spec = Gem::Specification.new do |s|
  s.name = 'postgres-pr'
  s.version = PostgresPR::VERSION
  s.summary = %q{A pure Ruby interface to the PostgreSQL (>= 7.4) database.}

  s.files = %w(README Rakefile) + Dir.glob("{lib,examples}/**/*")
  s.test_files = `git ls-files -- {test}/*`.split("\n")

  s.require_path = 'lib'

  s.authors = ["Michael Neumann", "Jeremy Evans", "Alexander E. Fischer", "Aaron Hamid", "Rahim Packir Saibo", "Lars Christensen", "Kashif Rasul"]
  s.email = ["mneumann@ntecs.de", "code@jeremyevans.net", "aef@raxys.net", "larsch@belunktum.dk", "kashif@nomad-labs.com"] 
  s.homepage = "https://github.com/kashif/em_postgresql"
  s.licenses = ["Ruby", "GPL"]
end

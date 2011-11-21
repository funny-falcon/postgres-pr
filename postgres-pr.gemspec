# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "postgres-pr/version"

spec = Gem::Specification.new do |s|
  s.name = 'postgres-pr'
  s.version = PostgresPR::VERSION
  s.summary = %q{A pure Ruby interface to the PostgreSQL (>= 7.4) database.}

  s.extensions = ["ext/postgres-pr/utils/extconf.rb"]
  s.files = %w(README Rakefile) + Dir.glob("{lib,examples}/**/*") + %w(ext/postgres-pr/utils/extconf.rb ext/postgres-pr/utils/string_unpack_single.c)
  s.test_files = `git ls-files -- {test}/*`.split("\n")

  s.require_paths = ['lib', 'ext']

  s.authors = ["Michael Neumann", "Jeremy Evans", "Alexander E. Fischer", "Aaron Hamid", "Rahim Packir Saibo", "Lars Christensen", "Kashif Rasul", "Sokolov Yura aka funny_falcon"]
  s.email = ["mneumann@ntecs.de", "code@jeremyevans.net", "aef@raxys.net", "larsch@belunktum.dk", "kashif@nomad-labs.com", "funny.falcon@gmail.com"]
  s.homepage = "https://github.com/funny-falcon/postgres-pr"
  s.licenses = ["Ruby", "GPL"]
end

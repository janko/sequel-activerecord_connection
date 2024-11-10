Gem::Specification.new do |spec|
  spec.name          = "sequel-activerecord_connection"
  spec.version       = "2.0.0"
  spec.authors       = ["Janko Marohnić"]
  spec.email         = ["janko@hey.com"]

  spec.summary       = %q{Allows Sequel to use ActiveRecord connection for database interaction.}
  spec.description   = %q{Allows Sequel to use ActiveRecord connection for database interaction.}
  spec.homepage      = "https://github.com/janko/sequel-activerecord_connection"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.5"

  spec.add_dependency "sequel", "~> 5.38"
  spec.add_dependency "activerecord", ">= 5.0", "< 8.1"

  spec.add_development_dependency "sequel_pg" unless RUBY_ENGINE == "jruby"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "warning"

  spec.files         = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb", "*.gemspec"]
  spec.require_paths = ["lib"]
end

Gem::Specification.new do |spec|
  spec.name          = "sequel-activerecord_connection"
  spec.version       = "1.2.2"
  spec.authors       = ["Janko Marohnić"]
  spec.email         = ["janko.marohnic@gmail.com"]

  spec.summary       = %q{Allows Sequel to use ActiveRecord connection for database interaction.}
  spec.description   = %q{Allows Sequel to use ActiveRecord connection for database interaction.}
  spec.homepage      = "https://github.com/janko/sequel-activerecord_connection"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.3"

  spec.add_dependency "sequel", "~> 5.16"
  spec.add_dependency "activerecord", ">= 4.2", "< 7"
  spec.add_dependency "after_commit_everywhere", "~> 0.1.5"

  spec.add_development_dependency "sequel", "~> 5.38"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "warning" if RUBY_VERSION >= "2.4"

  spec.files         = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb", "*.gemspec"]
  spec.require_paths = ["lib"]
end

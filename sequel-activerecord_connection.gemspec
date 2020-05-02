Gem::Specification.new do |spec|
  spec.name          = "sequel-activerecord_connection"
  spec.version       = "0.2.0"
  spec.authors       = ["Janko Marohnić"]
  spec.email         = ["janko.marohnic@gmail.com"]

  spec.summary       = %q{Allows Sequel to use ActiveRecord connection for database interaction.}
  spec.description   = %q{Allows Sequel to use ActiveRecord connection for database interaction.}
  spec.homepage      = "https://github.com/janko/sequel-activerecord_connection"
  spec.license       = "MIT"

  spec.required_ruby_version = Gem::Requirement.new(">= 2.2.0")

  spec.add_dependency "sequel", ">= 4.0", "< 6"
  spec.add_dependency "activerecord", ">= 5.0", "< 7"

  spec.add_development_dependency "pg",      "~> 1.0"
  spec.add_development_dependency "mysql2",  "~> 0.5"
  spec.add_development_dependency "sqlite3", "~> 1.3"
  spec.add_development_dependency "minitest"

  spec.files         = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb", "*.gemspec"]
  spec.require_paths = ["lib"]
end

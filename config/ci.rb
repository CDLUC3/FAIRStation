# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: Prepare database", "env RAILS_ENV=test bin/rails db:prepare"
  step "Tests: Rails", "bin/rails test"
  step "Autoloading", "bin/rails zeitwerk:check"
end

# This is a compatibility layer for using the pure Ruby postgres-pr instead of
# the C interface of postgres.

begin
  require 'pg.so'
rescue LoadError
  require 'postgres-pr/pg-compat'
end

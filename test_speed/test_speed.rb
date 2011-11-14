require 'benchmark'
$:.unshift File.join(File.dirname(__FILE__),'../lib')

require 'postgres-pr/connection'
c = PostgresPR::Connection.new('Intercable', 'yura')

big_str = 'a'*10000
Benchmark.bmbm(6) do |x|
  x.report("simple") do
    5000.times{ c.query('SELECT 1+2').rows }
  end
  x.report("select 1 row") do
    500.times{ c.query('select * from clients limit 1').rows }
  end
  x.report("select 100 rows") do
    50.times{ c.query('select * from clients limit 100').rows }
  end
  x.report("send bigstr") do 
    5000.times{ c.query("select substr('#{big_str}', 10, 1) as s").rows }
  end
end
